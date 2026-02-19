import { createAnthropic } from '@ai-sdk/anthropic';
import { createOpenAI } from '@ai-sdk/openai';
import { openrouter } from '@openrouter/ai-sdk-provider';

export type Preset = 'fast' | 'smart' | 'pro';
export type ProviderName = 'openrouter' | 'openai' | 'anthropic' | 'moonshot' | 'together' | 'minimax' | 'zai';

interface ModelEntry {
  id: string;
  label: string;
  provider: ProviderName;
  preset: Preset;
  toolUse: boolean;
  vision: boolean;
}

const REGISTRY: ModelEntry[] = [
  // Fast tier — cheap, quick responses
  { id: 'google/gemini-2.0-flash-001', label: 'Gemini 2.0 Flash (OpenRouter)', provider: 'openrouter', preset: 'fast', toolUse: true, vision: true },
  { id: 'kimi-k2-0905-preview', label: 'Kimi K2', provider: 'moonshot', preset: 'fast', toolUse: false, vision: false },
  { id: 'kimi-k2.5', label: 'Kimi K2.5 Code Plan', provider: 'moonshot', preset: 'smart', toolUse: true, vision: false },
  { id: 'MiniMax-M2.5-highspeed', label: 'MiniMax M2.5 HighSpeed', provider: 'minimax', preset: 'fast', toolUse: true, vision: false },
  { id: 'MiniMax-M2.1-highspeed', label: 'MiniMax M2.1 HighSpeed', provider: 'minimax', preset: 'fast', toolUse: true, vision: false },
  { id: 'glm-4.7-flash', label: 'GLM 4.7 Flash', provider: 'zai', preset: 'fast', toolUse: true, vision: false },
  { id: 'z-ai/glm-4.7-flash', label: 'GLM 4.7 Flash (OpenRouter)', provider: 'openrouter', preset: 'fast', toolUse: true, vision: false },
  // Smart tier — good balance
  { id: 'glm-4.7', label: 'GLM 4.7', provider: 'zai', preset: 'smart', toolUse: true, vision: false },
  { id: 'glm-4.5v', label: 'GLM 4.5V Vision', provider: 'zai', preset: 'smart', toolUse: false, vision: true },
  { id: 'MiniMax-M2.5', label: 'MiniMax M2.5', provider: 'minimax', preset: 'smart', toolUse: true, vision: false },
  { id: 'MiniMax-M2.1', label: 'MiniMax M2.1', provider: 'minimax', preset: 'smart', toolUse: true, vision: false },
  { id: 'z-ai/glm-4.7', label: 'GLM 4.7 (OpenRouter)', provider: 'openrouter', preset: 'smart', toolUse: true, vision: false },
  { id: 'z-ai/glm-4.5v', label: 'GLM 4.5V Vision (OpenRouter)', provider: 'openrouter', preset: 'smart', toolUse: false, vision: true },
  { id: 'openai/gpt-4o-mini', label: 'GPT-4o Mini (OpenRouter)', provider: 'openrouter', preset: 'smart', toolUse: true, vision: true },
  { id: 'gpt-4o-mini', label: 'GPT-4o Mini', provider: 'openai', preset: 'smart', toolUse: true, vision: true },
  { id: 'anthropic/claude-3.5-haiku', label: 'Claude 3.5 Haiku (OpenRouter)', provider: 'openrouter', preset: 'smart', toolUse: true, vision: true },
  // Pro tier — best quality
  { id: 'glm-5', label: 'GLM 5', provider: 'zai', preset: 'pro', toolUse: true, vision: false },
  { id: 'openai/gpt-4o', label: 'GPT-4o (OpenRouter)', provider: 'openrouter', preset: 'pro', toolUse: true, vision: true },
  { id: 'gpt-4o', label: 'GPT-4o', provider: 'openai', preset: 'pro', toolUse: true, vision: true },
  { id: 'anthropic/claude-3.5-sonnet', label: 'Claude 3.5 Sonnet (OpenRouter)', provider: 'openrouter', preset: 'pro', toolUse: true, vision: true },
];

interface DetectedKeys {
  openrouter?: string;
  openai?: string;
  anthropic?: string;
  moonshot?: string;
  together?: string;
  minimax?: string;
  zai?: string;
}

export function detectApiKeys(): DetectedKeys {
  return {
    openrouter: process.env.OPENROUTER_API_KEY,
    openai: process.env.OPENAI_API_KEY,
    anthropic: process.env.ANTHROPIC_API_KEY,
    moonshot: process.env.MOONSHOT_API_KEY,
    together: process.env.TOGETHER_API_KEY,
    minimax: process.env.MINIMAX_API_KEY,
    zai: process.env.ZAI_API_KEY,
  };
}

function isAvailable(entry: ModelEntry, keys: DetectedKeys): boolean {
  if (entry.provider === 'openrouter') return Boolean(keys.openrouter);
  if (entry.provider === 'minimax') return Boolean(keys.minimax);
  if (entry.provider === 'zai') return Boolean(keys.zai);
  return Boolean(keys[entry.provider]);
}

export function getAvailableModels(keys: DetectedKeys): ModelEntry[] {
  return REGISTRY.filter(m => isAvailable(m, keys));
}

export function pickBestModel(preset: Preset, keys: DetectedKeys): ModelEntry | null {
  const available = getAvailableModels(keys);
  // Prefer tool-use capable models first, then match preset
  const presetModels = available
    .filter(m => m.preset === preset)
    .sort((a, b) => (b.toolUse ? 1 : 0) - (a.toolUse ? 1 : 0));
  if (presetModels.length > 0) return presetModels[0];
  // Fallback: any available model with tool use
  const withTools = available.filter(m => m.toolUse);
  if (withTools.length > 0) return withTools[0];
  // Last resort: any available
  return available[0] || null;
}

/** Pick fastest available model, preferring direct providers over OpenRouter.
 *  Used by /api/command for low-latency, credit-independent responses. */
export function pickFastDirectModel(keys: DetectedKeys): ModelEntry | null {
  const available = getAvailableModels(keys);
  const fast = available.filter(m => m.preset === 'fast');
  // Prefer direct providers (no OpenRouter credit dependency)
  const direct = fast.filter(m => m.provider !== 'openrouter');
  if (direct.length > 0) return direct[0];
  // Fallback to any fast model (including OpenRouter)
  if (fast.length > 0) return fast[0];
  // Last resort: any direct model
  const anyDirect = available.filter(m => m.provider !== 'openrouter');
  return anyDirect[0] || available[0] || null;
}

export function findModel(nameOrId: string): ModelEntry | undefined {
  const lower = nameOrId.toLowerCase();
  // Exact match first (id or label), then fuzzy includes
  const exact = REGISTRY.find(m =>
    m.id.toLowerCase() === lower ||
    m.label.toLowerCase() === lower,
  );
  if (exact) return exact;
  return REGISTRY.find(m => m.id.toLowerCase().includes(lower));
}

function getApiKey(provider: ProviderName, keys: DetectedKeys): string {
  if (provider === 'openrouter') return keys.openrouter || '';
  if (provider === 'openai') return keys.openai || '';
  if (provider === 'anthropic') return keys.anthropic || '';
  if (provider === 'moonshot') return keys.moonshot || '';
  if (provider === 'minimax') return keys.minimax || '';
  if (provider === 'zai') return keys.zai || '';
  return keys.together || '';
}

/** Wrap fetch to inject thinking: disabled into Moonshot K2.5 requests */
function createMoonshotFetch(): typeof fetch {
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const wrapped = async (input: any, init?: any) => {
    if (init?.body && typeof init.body === 'string') {
      try {
        const body = JSON.parse(init.body);
        body.thinking = { type: 'disabled' };
        init = { ...init, body: JSON.stringify(body) };
      } catch { /* not JSON, pass through */ }
    }
    return globalThis.fetch(input, init);
  };
  return wrapped as typeof fetch;
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function createModel(entry: ModelEntry, keys: DetectedKeys): any {
  const apiKey = getApiKey(entry.provider, keys);

  if (entry.provider === 'openai') {
    const provider = createOpenAI({ apiKey });
    return provider.chat(entry.id);
  }

  if (entry.provider === 'moonshot') {
    const isK25 = entry.id.includes('k2.5');
    const provider = createOpenAI({
      baseURL: 'https://api.moonshot.ai/v1',
      apiKey,
      name: 'moonshot',
      // Disable thinking for K2.5 to avoid reasoning_content error with tools
      ...(isK25 ? { fetch: createMoonshotFetch() } : {}),
    });
    return provider.chat(entry.id);
  }

  if (entry.provider === 'zai') {
    const provider = createOpenAI({
      baseURL: 'https://api.z.ai/api/coding/paas/v4',
      apiKey,
      name: 'zai',
    });
    return provider.chat(entry.id);
  }

  if (entry.provider === 'minimax') {
    const provider = createOpenAI({
      baseURL: 'https://api.minimax.io/v1',
      apiKey,
      name: 'minimax',
    });
    return provider.chat(entry.id);
  }

  if (entry.provider === 'together') {
    const provider = createOpenAI({
      baseURL: 'https://api.together.xyz/v1',
      apiKey,
      name: 'together',
    });
    return provider.chat(entry.id);
  }

  // Default: OpenRouter
  return openrouter(entry.id, { apiKey });
}

export function formatModelList(keys: DetectedKeys, currentId?: string): string {
  const available = getAvailableModels(keys);
  if (available.length === 0) return 'No models available. Set at least one API key.';

  const lines: string[] = ['Available models:'];
  const presets: Preset[] = ['fast', 'smart', 'pro'];
  for (const preset of presets) {
    const models = available.filter(m => m.preset === preset);
    if (models.length === 0) continue;
    lines.push(`  ${preset.toUpperCase()}:`);
    for (const m of models) {
      const current = m.id === currentId ? ' ← current' : '';
      const tools = m.toolUse ? '✓tools' : '✗tools';
      lines.push(`    ${m.label} (${m.id}) [${tools}]${current}`);
    }
  }
  return lines.join('\n');
}
