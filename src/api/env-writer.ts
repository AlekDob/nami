import { resolve } from 'path';

const ENV_PATH = resolve(process.cwd(), '.env');

const PROVIDER_ENV_MAP: Record<string, string> = {
  openrouter: 'OPENROUTER_API_KEY',
  openai: 'OPENAI_API_KEY',
  anthropic: 'ANTHROPIC_API_KEY',
  moonshot: 'MOONSHOT_API_KEY',
  together: 'TOGETHER_API_KEY',
  elevenlabs: 'ELEVENLABS_API_KEY',
};

const PROVIDER_LABELS: Record<string, string> = {
  openrouter: 'OpenRouter',
  openai: 'OpenAI',
  anthropic: 'Anthropic',
  moonshot: 'Moonshot',
  together: 'Together',
  elevenlabs: 'ElevenLabs',
};

export interface ProviderKeyStatus {
  id: string;
  label: string;
  configured: boolean;
  maskedKey?: string;
}

function maskKey(key: string): string {
  if (key.length <= 8) return '****';
  return key.slice(0, 3) + '...' + key.slice(-4);
}

async function parseEnv(): Promise<Map<string, string>> {
  const map = new Map<string, string>();
  try {
    const content = await Bun.file(ENV_PATH).text();
    for (const line of content.split('\n')) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;
      const eqIdx = trimmed.indexOf('=');
      if (eqIdx === -1) continue;
      const key = trimmed.slice(0, eqIdx).trim();
      let value = trimmed.slice(eqIdx + 1).trim();
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.slice(1, -1);
      }
      map.set(key, value);
    }
  } catch {
    // .env doesn't exist yet
  }
  return map;
}

async function writeEnv(map: Map<string, string>): Promise<void> {
  const lines: string[] = [];
  for (const [key, value] of map) {
    lines.push(`${key}=${value}`);
  }
  await Bun.write(ENV_PATH, lines.join('\n') + '\n');
}

export async function getProviderKeys(): Promise<ProviderKeyStatus[]> {
  const env = await parseEnv();
  return Object.entries(PROVIDER_ENV_MAP).map(([id, envVar]) => {
    const value = env.get(envVar) || '';
    return {
      id,
      label: PROVIDER_LABELS[id] || id,
      configured: value.length > 0,
      maskedKey: value.length > 0 ? maskKey(value) : undefined,
    };
  });
}

export async function setProviderKey(providerId: string, key: string): Promise<void> {
  const envVar = PROVIDER_ENV_MAP[providerId];
  if (!envVar) throw new Error(`Unknown provider: ${providerId}`);
  const env = await parseEnv();
  env.set(envVar, key);
  await writeEnv(env);
  process.env[envVar] = key;
}

export async function deleteProviderKey(providerId: string): Promise<void> {
  const envVar = PROVIDER_ENV_MAP[providerId];
  if (!envVar) throw new Error(`Unknown provider: ${providerId}`);
  const env = await parseEnv();
  env.delete(envVar);
  await writeEnv(env);
  delete process.env[envVar];
}

export interface MCPServerInfo {
  name: string;
  status: 'configured' | 'disabled';
}

export async function getMcpServers(): Promise<MCPServerInfo[]> {
  try {
    const path = resolve(process.cwd(), '.mcp.json');
    const content = await Bun.file(path).text();
    const config = JSON.parse(content) as { mcpServers?: Record<string, unknown> };
    const servers = config.mcpServers || {};
    return Object.keys(servers).map(name => ({
      name,
      status: 'configured' as const,
    }));
  } catch {
    return [];
  }
}
