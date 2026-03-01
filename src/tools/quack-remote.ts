import { tool } from 'ai';
import { z } from 'zod';

const MAC_URL = process.env.MAC_AGENT_URL;
const MAC_TOKEN = process.env.MAC_AGENT_TOKEN;

/**
 * Proxy fetch to Quack Remote API via Mac agent.
 * Quack listens on 127.0.0.1:6769 on the Mac — unreachable from Hetzner.
 * We use the Mac agent's /exec endpoint to run curl locally.
 */
async function quackFetch(
  method: string,
  path: string,
  body?: Record<string, unknown>,
): Promise<{ success: boolean; data?: unknown; error?: string }> {
  if (!MAC_URL || !MAC_TOKEN) {
    return { success: false, error: 'Mac agent not configured' };
  }

  // Read Quack config from Mac to get port + token
  const configCmd =
    'cat ~/Library/Application\\ Support/com.quack.terminal/quack-remote.json';

  const configRes = await fetch(`${MAC_URL}/exec`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${MAC_TOKEN}`,
    },
    body: JSON.stringify({ command: configCmd }),
    signal: AbortSignal.timeout(10_000),
  });

  const configData = (await configRes.json()) as {
    stdout?: string;
    error?: string;
  };

  if (!configRes.ok || !configData.stdout) {
    return {
      success: false,
      error: configData.error || 'Failed to read Quack config',
    };
  }

  let port: number;
  let token: string;
  try {
    const raw = JSON.parse(configData.stdout) as {
      remote?: { enabled: boolean; port: number; token: string };
      enabled?: boolean;
      port?: number;
      token?: string;
    };
    // Config may be nested under "remote" key or flat
    const cfg = raw.remote ?? raw;
    if (!cfg.enabled) {
      return { success: false, error: 'Quack Remote API is disabled' };
    }
    if (!cfg.port || !cfg.token) {
      return { success: false, error: 'Quack config missing port or token' };
    }
    port = cfg.port;
    token = cfg.token;
  } catch {
    return { success: false, error: 'Invalid Quack config JSON' };
  }

  // Build curl command
  const url = `http://127.0.0.1:${port}/api${path}`;
  let curlCmd = `curl -s -X ${method} -H "Authorization: Bearer ${token}"`;
  if (body) {
    const jsonBody = JSON.stringify(body).replace(/"/g, '\\"');
    curlCmd += ` -H "Content-Type: application/json" -d "${jsonBody}"`;
  }
  curlCmd += ` "${url}"`;

  const res = await fetch(`${MAC_URL}/exec`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${MAC_TOKEN}`,
    },
    body: JSON.stringify({ command: curlCmd }),
    signal: AbortSignal.timeout(30_000),
  });

  const data = (await res.json()) as {
    stdout?: string;
    stderr?: string;
    error?: string;
  };

  if (!res.ok) {
    return { success: false, error: data.error || 'Mac agent error' };
  }

  try {
    const parsed = JSON.parse(data.stdout || '{}');
    return { success: true, data: parsed };
  } catch {
    return {
      success: true,
      data: { raw: data.stdout },
    };
  }
}

export const quackStatus = tool({
  description:
    'Check if Quack is running on the Mac. Returns version, uptime, agent count, active sessions.',
  inputSchema: z.object({}),
  execute: async () => {
    try {
      return await quackFetch('GET', '/status');
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return { success: false, error: msg };
    }
  },
});

export const quackAgents = tool({
  description:
    'List all Quack agents with their status, project, role, and what they are working on.',
  inputSchema: z.object({}),
  execute: async () => {
    try {
      return await quackFetch('GET', '/agents');
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return { success: false, error: msg };
    }
  },
});

export const quackExecute = tool({
  description:
    'Execute a prompt on a specific Quack agent. Creates a new session and starts the task. Returns the session ID for monitoring.',
  inputSchema: z.object({
    agentId: z.string().describe('UUID of the Quack agent'),
    prompt: z.string().describe('The task/prompt to execute'),
    projectPath: z
      .string()
      .describe(
        'Optional project path override. Leave empty to use agent default.',
      ),
  }),
  execute: async ({ agentId, prompt, projectPath }) => {
    try {
      const body: Record<string, unknown> = { agentId, prompt };
      if (projectPath) body.projectPath = projectPath;
      return await quackFetch('POST', '/execute', body);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return { success: false, error: msg };
    }
  },
});

export const quackSessions = tool({
  description:
    'List all Quack sessions sorted by creation time. Shows title, agent, status, and message count.',
  inputSchema: z.object({}),
  execute: async () => {
    try {
      return await quackFetch('GET', '/sessions');
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return { success: false, error: msg };
    }
  },
});

export const quackSessionMessages = tool({
  description:
    'Get the conversation messages for a Quack session. Returns the full chat history.',
  inputSchema: z.object({
    sessionId: z.string().describe('UUID of the session'),
  }),
  execute: async ({ sessionId }) => {
    try {
      return await quackFetch('GET', `/sessions/${sessionId}/messages`);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return { success: false, error: msg };
    }
  },
});

export const quackSessionSend = tool({
  description:
    'Send a follow-up message to an active Quack session. Continues the conversation with the agent.',
  inputSchema: z.object({
    sessionId: z.string().describe('UUID of the active session'),
    message: z.string().describe('The message to send'),
  }),
  execute: async ({ sessionId, message }) => {
    try {
      return await quackFetch('POST', `/sessions/${sessionId}/send`, {
        message,
      });
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return { success: false, error: msg };
    }
  },
});

export const quackJobs = tool({
  description:
    'List all Quack automation jobs with cron schedule, status, and last run info.',
  inputSchema: z.object({}),
  execute: async () => {
    try {
      return await quackFetch('GET', '/jobs');
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return { success: false, error: msg };
    }
  },
});

export const quackJobFire = tool({
  description: 'Manually fire a Quack automation job immediately.',
  inputSchema: z.object({
    jobId: z.string().describe('UUID of the job to fire'),
  }),
  execute: async ({ jobId }) => {
    try {
      return await quackFetch('POST', `/jobs/${jobId}/fire`);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return { success: false, error: msg };
    }
  },
});

export const quackJobToggle = tool({
  description: 'Enable or disable a Quack automation job.',
  inputSchema: z.object({
    jobId: z.string().describe('UUID of the job to toggle'),
  }),
  execute: async ({ jobId }) => {
    try {
      return await quackFetch('POST', `/jobs/${jobId}/toggle`);
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return { success: false, error: msg };
    }
  },
});
