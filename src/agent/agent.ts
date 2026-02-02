import { generateText, stepCountIs, type ModelMessage } from 'ai';
import { openrouter } from "@openrouter/ai-sdk-provider";
import type { AgentConfig } from '../config/types.js';
import { MemoryStore } from '../memory/store.js';
import { SkillLoader } from '../skills/loader.js';
import { SoulLoader } from '../soul/soul.js';
import { buildTools } from '../tools/index.js';
import { buildSystemPrompt } from './system-prompt.js';
import { shouldFlush, runMemoryFlush } from './flush.js';
import type { Scheduler } from '../scheduler/cron.js';
import {
  detectApiKeys,
  pickBestModel,
  findModel,
  createModel,
  formatModelList,
  type Preset,
} from '../config/models.js';

const DEFAULT_USER_ID = 'default';
const DEFAULT_DATA_DIR = './data';
const MAX_STEPS = 10;
const CONTEXT_WINDOW = 128_000;

export type ToolEventCallback = (toolName: string) => void;

export interface RunStats {
  model: string;
  inputTokens: number;
  outputTokens: number;
  durationMs: number;
}

export class Agent {
  private memory: MemoryStore;
  private skills: SkillLoader;
  private soul: SoulLoader;
  private tools: ReturnType<typeof buildTools>;
  private scheduler: Scheduler | null = null;
  private keys = detectApiKeys();
  private currentModelId: string | null = null;
  private isFirstRun = false;
  lastRunStats: RunStats | null = null;
  onToolUse: ToolEventCallback | null = null;

  constructor(
    public config: AgentConfig,
    dataDir: string = DEFAULT_DATA_DIR,
    userId: string = DEFAULT_USER_ID,
  ) {
    this.memory = new MemoryStore(dataDir, userId);
    this.skills = new SkillLoader(dataDir);
    this.soul = new SoulLoader(dataDir);
    this.tools = buildTools(this.memory);
  }

  /** Attach scheduler so agent gets reminder tools */
  attachScheduler(scheduler: Scheduler): void {
    this.scheduler = scheduler;
    this.tools = buildTools(this.memory, scheduler);
  }

  async init(): Promise<void> {
    await this.memory.init();
    this.isFirstRun = !(await this.soul.exists());
    if (this.isFirstRun) {
      await this.soul.createDefault();
    }

    const preset = (process.env.MODEL_PRESET as Preset) || 'smart';
    const envModel = this.config.modelName;
    if (envModel) {
      const found = findModel(envModel);
      this.currentModelId = found ? found.id : envModel;
    } else {
      const best = pickBestModel(preset, this.keys);
      this.currentModelId = best?.id || null;
    }
  }

  get needsOnboarding(): boolean {
    return this.isFirstRun;
  }

  completeOnboarding(): void {
    this.isFirstRun = false;
  }

  async run(messages: ModelMessage[]): Promise<string> {
    if (!this.currentModelId) {
      return 'Error: No model available. Set an API key.';
    }

    const startTime = Date.now();
    this.lastRunStats = null;

    try {
      if (shouldFlush(messages, CONTEXT_WINDOW)) {
        await runMemoryFlush(
          () => this.resolveModel(),
          this.tools,
          messages,
        );
      }

      const memoryContext = await this.memory.buildPromptContext();
      const loadedSkills = await this.skills.loadAll();
      const skillsContext = this.skills.buildContext(loadedSkills);
      const soulContent = await this.soul.read();
      const soulContext = this.soul.buildContext(soulContent);
      const onboarding = this.isFirstRun
        ? this.soul.buildOnboardingPrompt()
        : undefined;

      const systemPrompt = buildSystemPrompt(memoryContext, {
        skillsContext,
        soulContext,
        onboarding,
      });

      const onToolUse = this.onToolUse;

      const result = await generateText({
        model: this.resolveModel(),
        system: systemPrompt,
        messages,
        tools: this.tools,
        stopWhen: stepCountIs(MAX_STEPS),
        onStepFinish: (step) => {
          if (!onToolUse) return;
          const calls = (step as Record<string, unknown>).toolCalls;
          if (!Array.isArray(calls)) return;
          for (const call of calls) {
            if (call && typeof call === 'object' && 'toolName' in call) {
              onToolUse(String(call.toolName));
            }
          }
        },
      });

      const usage = result.usage || { inputTokens: 0, outputTokens: 0 };
      const entry = this.currentModelId
        ? findModel(this.currentModelId) : null;
      this.lastRunStats = {
        model: entry?.label || this.currentModelId || 'unknown',
        inputTokens: usage.inputTokens ?? 0,
        outputTokens: usage.outputTokens ?? 0,
        durationMs: Date.now() - startTime,
      };

      const userMsg = this.lastUserMessage(messages);
      await this.memory.appendToDaily(
        '**User**: ' + userMsg + '\n**Meow**: ' + result.text.slice(0, 500),
      );

      return result.text;
    } catch (error) {
      const msg = error instanceof Error ? error.message : String(error);
      return 'Error: ' + msg;
    }
  }

  private isMoonshotModel(): boolean {
    const entry = this.currentModelId
      ? findModel(this.currentModelId) : null;
    return entry?.provider === 'moonshot';
  }

  setModel(nameOrId: string): string {
    const found = findModel(nameOrId);
    if (found) {
      this.currentModelId = found.id;
      const tools = found.toolUse
        ? '(tools: yes)'
        : '(tools: no)';
      return 'Switched to ' + found.label + ' ' + tools;
    }
    this.currentModelId = nameOrId;
    return 'Switched to ' + nameOrId + ' (custom)';
  }

  getModelInfo(): string {
    const entry = this.currentModelId
      ? findModel(this.currentModelId)
      : null;
    if (entry) {
      const tools = entry.toolUse ? 'yes' : 'no';
      return entry.label + ' [' + entry.preset + '] (tools: ' + tools + ')';
    }
    return this.currentModelId || 'none';
  }

  supportsVision(): boolean {
    const entry = this.currentModelId
      ? findModel(this.currentModelId)
      : null;
    return entry?.vision ?? false;
  }

  listModels(): string {
    return formatModelList(this.keys, this.currentModelId || undefined);
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  private resolveModel(): any {
    const entry = this.currentModelId
      ? findModel(this.currentModelId)
      : null;
    if (entry) return createModel(entry, this.keys);
    return openrouter(this.currentModelId || '', {
      apiKey: this.keys.openrouter,
    });
  }

  private lastUserMessage(messages: ModelMessage[]): string {
    const last = [...messages].reverse().find(m => m.role === 'user');
    if (!last) return '[unknown]';
    if (typeof last.content === 'string') return last.content;
    if (Array.isArray(last.content)) {
      for (const part of last.content) {
        if (part.type === 'text') return part.text;
      }
      for (const part of last.content) {
        if (part.type === 'image') return '[image]';
      }
    }
    return '[unknown]';
  }

  getMemoryStore(): MemoryStore {
    return this.memory;
  }
}
