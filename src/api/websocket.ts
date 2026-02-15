import type { ServerWebSocket } from 'bun';
import type { Agent } from '../agent/agent.js';
import type { ModelMessage } from 'ai';
import type { WsClientMessage, WsServerMessage, MessageContent } from './types.js';
import { validateKey } from './auth.js';
import { sendPushNotification } from '../channels/apns.js';
import type { SessionStore } from '../sessions/store.js';

type WsData = { id: string; authenticated: boolean };

const connections = new Map<string, ServerWebSocket<WsData>>();
let agentRef: Agent | null = null;
let sessionsRef: SessionStore | null = null;

let connCounter = 0;

export function setAgent(agent: Agent): void {
  agentRef = agent;
}

export function setSessions(sessions: SessionStore): void {
  sessionsRef = sessions;
}

function send(ws: ServerWebSocket<WsData>, msg: WsServerMessage): void {
  const logType = (msg as Record<string, unknown>).type;
  console.log(`[WS] → ${ws.data.id} | type: ${logType}`);
  ws.send(JSON.stringify(msg));
}

/** Broadcast notification to all connected WebSocket clients */
/** Broadcast creation event to all connected WebSocket clients */
export function broadcastCreation(
  id: string,
  name: string,
  creationType: string,
): void {
  const msg: WsServerMessage = { type: "creation", id, name, creationType };
  const payload = JSON.stringify(msg);
  for (const ws of connections.values()) {
    ws.send(payload);
  }
}

export function broadcastNotification(
  title: string,
  body: string,
): void {
  const msg: WsServerMessage = { type: 'notification', title, body };
  const payload = JSON.stringify(msg);
  for (const ws of connections.values()) {
    ws.send(payload);
  }
}

async function handleChat(
  ws: ServerWebSocket<WsData>,
  messages: Array<{ role: 'user' | 'assistant'; content: MessageContent }>,
  clientSessionId?: string,
): Promise<void> {
  if (!agentRef) {
    send(ws, { type: 'error', error: 'Agent not initialized' });
    return;
  }
  const hasImages = messages.some(m =>
    Array.isArray(m.content) && m.content.some(p => p.type === 'image')
  );
  if (hasImages && !agentRef.supportsVision()) {
    send(ws, { type: 'error', error: 'Current model does not support images. Switch to a vision-capable model.' });
    return;
  }

  const msgs: ModelMessage[] = messages.map((m) => ({
    role: m.role,
    content: m.content,
  }));

  console.log(`[WS] Chat started for ${ws.data.id}, messages: ${messages.length}`);
  // Stream tool usage events to the client
  const previousCallback = agentRef.onToolUse;
  agentRef.onToolUse = (toolName: string) => {
    send(ws, { type: 'tool_use', tool: toolName });
    if (previousCallback) previousCallback(toolName);
  };

  try {
    const text = await agentRef.run(msgs);
    agentRef.onToolUse = previousCallback;
    const stats = agentRef.lastRunStats;

    // Persist to session
    let sessionId = clientSessionId;
    if (sessionsRef) {
      if (!sessionId) {
        const s = await sessionsRef.createSession('api');
        sessionId = s.id;
      }
      const lastUser = messages[messages.length - 1];
      if (lastUser) {
        const userText = typeof lastUser.content === 'string'
          ? lastUser.content
          : lastUser.content.filter(p => p.type === 'text').map(p => (p as { text: string }).text).join(' ');
        await sessionsRef.appendMessage(sessionId, 'user', userText);
      }
      await sessionsRef.appendMessage(sessionId, 'assistant', text);
    }

    send(ws, {
      type: 'done',
      text,
      sessionId,
      stats: stats || {
        model: 'unknown',
        inputTokens: 0,
        outputTokens: 0,
        durationMs: 0,
      },
    });
    sendPushNotification("Nami", text.slice(0, 200), sessionId).then(() => console.log("[APNs] Push sent")).catch((e) => console.error("[APNs] Push failed:", e));
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    send(ws, { type: 'error', error: msg });
  }
}

export const wsHandlers = {
  open(ws: ServerWebSocket<WsData>): void {
    connections.set(ws.data.id, ws);
    console.log(`[WS] Client connected: ${ws.data.id} (total: ${connections.size})`);
  },

  message(ws: ServerWebSocket<WsData>, raw: string | Buffer): void {
    const text = typeof raw === 'string' ? raw : raw.toString();
    let parsed: WsClientMessage;
    try {
      parsed = JSON.parse(text) as WsClientMessage;
    } catch {
      send(ws, { type: 'error', error: 'Invalid JSON' });
      return;
    }

    if (parsed.type === 'ping') {
      send(ws, { type: 'pong' });
      return;
    }

    if (parsed.type === 'chat') {
      handleChat(ws, parsed.messages, parsed.sessionId).catch(() => {
        send(ws, { type: 'error', error: 'Internal error' });
      });
      return;
    }

    send(ws, { type: 'error', error: 'Unknown message type' });
  },

  close(ws: ServerWebSocket<WsData>): void {
    console.log(`[WS] Client disconnected: ${ws.data.id} (remaining: ${connections.size - 1})`);
    connections.delete(ws.data.id);
  },
};

export function handleUpgrade(
  req: Request,
  server: { upgrade: (req: Request, opts: { data: WsData }) => boolean },
): Response | undefined {
  const url = new URL(req.url);
  const key = url.searchParams.get('key') || '';

  if (!validateKey(key)) {
    return new Response('Unauthorized', { status: 401 });
  }

  connCounter++;
  const id = 'ws-' + connCounter;
  const ok = server.upgrade(req, {
    data: { id, authenticated: true } satisfies WsData,
  });
  if (ok) return undefined;
  return new Response('Upgrade failed', { status: 500 });
}
