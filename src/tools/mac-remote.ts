import { tool } from 'ai';
import { z } from 'zod';

const MAC_URL = process.env.MAC_AGENT_URL;
const MAC_TOKEN = process.env.MAC_AGENT_TOKEN;

function macAvailable(): boolean {
  return Boolean(MAC_URL && MAC_TOKEN);
}

async function macFetch(
  path: string,
  init?: RequestInit,
): Promise<Response> {
  return fetch(`${MAC_URL}${path}`, {
    ...init,
    headers: {
      ...init?.headers,
      Authorization: `Bearer ${MAC_TOKEN}`,
    },
    signal: AbortSignal.timeout(30_000),
  });
}

export const macFileRead = tool({
  description:
    "Read a file from Alek's Mac. Use absolute paths like /Users/alekdob/Downloads/file.pdf. Returns text content for text files. Only works when the Mac is online.",
  inputSchema: z.object({
    path: z.string().describe('Absolute file path on the Mac'),
  }),
  execute: async ({ path }) => {
    if (!macAvailable()) {
      return { error: 'Mac agent not configured' };
    }

    try {
      const res = await macFetch(
        `/file?path=${encodeURIComponent(path)}`,
      );

      if (!res.ok) {
        const err = await res.json() as { error: string };
        return { error: err.error };
      }

      const contentType = res.headers.get('content-type') || '';
      const fileSize = res.headers.get('x-file-size') || '0';

      if (contentType.startsWith('text/') || contentType.includes('json')) {
        const content = await res.text();
        return { content, fileSize, contentType };
      }

      // Binary files — return base64
      const buf = await res.arrayBuffer();
      const base64 = Buffer.from(buf).toString('base64');
      return {
        content: `[Binary file: ${contentType}, ${fileSize} bytes]`,
        base64: base64.slice(0, 500) + (base64.length > 500 ? '...' : ''),
        fileSize,
        contentType,
      };
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      if (msg.includes('timeout') || msg.includes('ECONNREFUSED')) {
        return { error: 'Mac is offline or unreachable' };
      }
      return { error: msg };
    }
  },
});

export const macExec = tool({
  description:
    "Execute a whitelisted command on Alek's Mac. Allowed: open, ls, say, osascript, pbcopy, pbpaste, screencapture, date, uptime, whoami, sw_vers, df, pmset, defaults read. Only works when the Mac is online.",
  inputSchema: z.object({
    command: z.string().describe('The command to execute'),
  }),
  execute: async ({ command }) => {
    if (!macAvailable()) {
      return { error: 'Mac agent not configured' };
    }

    try {
      const res = await macFetch('/exec', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ command }),
      });

      const data = await res.json() as {
        success?: boolean;
        stdout?: string;
        stderr?: string;
        error?: string;
      };

      if (!res.ok) return { error: data.error };
      return data;
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      if (msg.includes('timeout') || msg.includes('ECONNREFUSED')) {
        return { error: 'Mac is offline or unreachable' };
      }
      return { error: msg };
    }
  },
});
