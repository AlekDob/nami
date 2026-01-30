import { createOpenAI } from '@ai-sdk/openai';
import { openrouter } from '@openrouter/ai-sdk-provider';

export type Preset = 'fast' | 'smart' | 'pro';
export type ProviderName = 'openrouter' | 'openai' | 'anthropic' | 'moonshot' | 'together';

interface ModelEntry {
  id: string;
  label: string;
  provider: ProviderName;
  preset: Preset;
  toolUse: boolean;
}

const REGISTRY: ModelEntry[] = [
  // Fast tier — cheap, quick responses
  { id: 'google/gemini-2.0-flash-001', label: 'Gemini 2.0 Flash', provider: 'openrouter', preset: 'fast', toolUse: true },
  { id: 'kimi-k2-0905-preview', label: 'Kimi K2', provider: 'moonshot', preset: 'fast', toolUse: false },
  { id: 'minimax/minimax-m2.1', label: 'MiniMax M2.1', provider: 'openrouter', preset: 'fast', toolUse: false },
  // Smart tier — good balance
  { id: 'openai/gpt-4o-mini', label: 'GPT-4o Mini', provider: 'openrouter', preset: 'smart', toolUse: true },
  { id: 'gpt-4o-mini', label: 'GPT-4o Mini (direct)', provider: 'openai', preset: 'smart', toolUse: true },
  { id: 'anthropic/claude-3.5-haiku', label: 'Claude 3.5 Haiku', provider: 'openrouter', preset: 'smart', toolUse: true },
  // Pro tier — best quality
  { id: 'openai/gpt-4o', label: 'GPT-4o', provider: 'openrouter', preset: 'pro', toolUse: true },
  { id: 'gpt-4o', label: 'GPT-4o (direct)', provider: 'openai', preset: 'pro', toolUse: true },
  { id: 'anthropic/claude-3.5-sonnet', label: 'Claude 3.5 Sonnet', provider: 'openrouter', preset: 'pro', toolUse: true },
];

interface DetectedKeys {
  openrouter?: string;
  openai?: string;
  anthropic?: string;
  moonshot?: string;
  together?: string;
}

export function detectApiKeys(): DetectedKeys {
  return {
    openrouter: process.env.OPENROUTER_API_KEY,
    openai: process.env.OPENAI_API_KEY,
    anthropic: process.env.ANTHROPIC_API_KEY,
    moonshot: process.env.MOONSHOT_API_KEY,
    together: process.env.TOGETHER_API_KEY,
  };
}

function isAvailable(entry: ModelEntry, keys: DetectedKeys): boolean {
  if (entry.provider === 'openrouter') return Boolean(keys.openrouter);
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

export function findModel(nameOrId: string): ModelEntry | undefined {
  const lower = nameOrId.toLowerCase();
  return REGISTRY.find(m =>
    m.id.toLowerCase() === lower ||
    m.label.toLowerCase() === lower ||
    m.id.toLowerCase().includes(lower),
  );
}

function getApiKey(provider: ProviderName, keys: DetectedKeys): string {
  if (provider === 'openrouter') return keys.openrouter || '';
  if (provider === 'openai') return keys.openai || '';
  if (provider === 'anthropic') return keys.anthropic || '';
  if (provider === 'moonshot') return keys.moonshot || '';
  return keys.together || '';
}

// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function createModel(entry: ModelEntry, keys: DetectedKeys): any {
  const apiKey = getApiKey(entry.provider, keys);

  if (entry.provider === 'openai') {
    const provider = createOpenAI({ apiKey });
    return provider.chat(entry.id);
  }

  if (entry.provider === 'moonshot') {
    const provider = createOpenAI({
      baseURL: 'https://api.moonshot.ai/v1',
      apiKey,
      name: 'moonshot',
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
