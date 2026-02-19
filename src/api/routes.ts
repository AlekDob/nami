import { detectApiKeys, getAvailableModels } from '../config/models.js';
import type { Agent } from '../agent/agent.js';
import type { Scheduler } from '../scheduler/cron.js';
import type { SoulLoader } from '../soul/soul.js';
import type { ModelMessage } from 'ai';
import type {
  ChatRequest, ChatResponse, StatusResponse,
  MemorySearchResponse, MemoryLinesResponse, MemoryRecentResponse,
  JobCreateRequest, ApiError, MessageContent,
  ShoppingListRequest, ShoppingListResponse,
  CommandRequest, CommandResponse,
} from './types.js';
import { readFile, writeFile, mkdir } from 'fs/promises';
import { resolve } from 'path';
import { loadCommands, saveCommands } from '../tools/local-command.js';
import type { StoredCommand } from '../tools/local-command.js';

import { registerDevice, unregisterDevice } from '../channels/apns.js';
import { listCreations, getCreation, getCreationPreview, deleteCreation } from './creations.js';
import { getProviderKeys, setProviderKey, deleteProviderKey, getMcpServers } from './env-writer.js';
import type { SessionStore } from '../sessions/store.js';

const startedAt = Date.now();

interface RouteContext {
  agent: Agent;
  scheduler: Scheduler;
  soul: SoulLoader;
  sessions: SessionStore;
}

type Handler = (
  req: Request,
  ctx: RouteContext,
  params: Record<string, string>,
) => Promise<Response>;

function json<T>(data: T, status = 200): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function err(message: string, code: number): Response {
  return json<ApiError>({ error: message, code }, code);
}

// ---------- Handlers ----------

const postChat: Handler = async (req, { agent, sessions }) => {
  const body = (await req.json()) as ChatRequest;
  if (!body.messages?.length) return err('messages required', 400);

  const hasImages = body.messages.some(m =>
    Array.isArray(m.content) && m.content.some(p => p.type === 'image')
  );
  if (hasImages && !agent.supportsVision()) {
    return err('Current model does not support images. Switch to a vision-capable model.', 400);
  }

  const msgs = body.messages.map((m) => ({
    role: m.role as 'user' | 'assistant',
    content: m.content,
  })) as ModelMessage[];

  const toolsUsed: string[] = [];
  const previousCallback = agent.onToolUse;
  agent.onToolUse = (toolName: string) => {
    toolsUsed.push(toolName);
    if (previousCallback) previousCallback(toolName);
  };

  const text = await agent.run(msgs);
  agent.onToolUse = previousCallback;
  const stats = agent.lastRunStats;
  // Persist to session
  let sessionId = body.sessionId;
  if (!sessionId) {
    const session = await sessions.createSession('api');
    sessionId = session.id;
  }
  const lastUserMsg = body.messages[body.messages.length - 1];
  if (lastUserMsg) {
    const userContent = typeof lastUserMsg.content === 'string'
      ? lastUserMsg.content
      : lastUserMsg.content.filter(p => p.type === 'text').map(p => (p as { text: string }).text).join(' ');
    await sessions.appendMessage(sessionId, 'user', userContent);
  }
  await sessions.appendMessage(sessionId, 'assistant', text);

  const resp: ChatResponse = {
    text,
    sessionId,
    toolsUsed: toolsUsed.length > 0 ? toolsUsed : undefined,
    stats: stats || {
      model: 'unknown',
      inputTokens: 0,
      outputTokens: 0,
      durationMs: 0,
    },
  };
  return json(resp);
};

const postCommand: Handler = async (req, { agent }) => {
  const body = (await req.json()) as CommandRequest;
  if (!body.prompt?.trim()) return err('prompt required', 400);

  const { result, model, durationMs } = await agent.runCommand(body.prompt);
  const resp: CommandResponse = {
    result,
    stats: { model, durationMs },
  };
  return json(resp);
};

const getStatus: Handler = async (_req, { agent }) => {
  const mem = process.memoryUsage();
  const resp: StatusResponse = {
    uptime: Math.floor((Date.now() - startedAt) / 1000),
    model: agent.getModelInfo(),
    memory: {
      rss: Math.round(mem.rss / 1024 / 1024),
      heap: Math.round(mem.heapUsed / 1024 / 1024),
    },
    channels: ['cli', 'api'],
  };
  return json(resp);
};

const getModels: Handler = async (_req, { agent }) => {
  return json({ models: agent.listModels() });
};

const putModel: Handler = async (req, { agent }) => {
  const { id } = (await req.json()) as { id: string };
  if (!id) return err('id required', 400);
  const msg = agent.setModel(id);
  return json({ message: msg });
};

const getMemorySearch: Handler = async (req, { agent }) => {
  const url = new URL(req.url);
  const query = url.searchParams.get('q') || '';
  if (!query) return err('q parameter required', 400);

  const results = await agent.getMemoryStore().search(query);
  const resp: MemorySearchResponse = { query, results };
  return json(resp);
};

const getMemoryLines: Handler = async (req, { agent }) => {
  const url = new URL(req.url);
  const path = url.searchParams.get('path') || '';
  const from = parseInt(url.searchParams.get('from') || '1', 10);
  const count = parseInt(url.searchParams.get('count') || '20', 10);
  if (!path) return err('path parameter required', 400);

  const text = await agent.getMemoryStore().getLines(path, from, count);
  const resp: MemoryLinesResponse = { path, from, count, text };
  return json(resp);
};

const getMemoryRecent: Handler = async (req, { agent }) => {
  const url = new URL(req.url);
  const limit = parseInt(url.searchParams.get('limit') || '10', 10);
  const results = await agent.getMemoryStore().recentEntries(Math.min(limit, 30));
  const resp: MemoryRecentResponse = { results };
  return json(resp);
};

const getJobs: Handler = async (_req, { scheduler }) => {
  return json({ jobs: scheduler.listJobs() });
};

const postJob: Handler = async (req, { scheduler }) => {
  const body = (await req.json()) as JobCreateRequest;
  if (!body.name || !body.cron || !body.task) {
    return err('name, cron, task required', 400);
  }
  const job = await scheduler.addJob({
    name: body.name,
    cron: body.cron,
    task: body.task,
    userId: body.userId || 'default',
    enabled: true,
    notify: body.notify ?? true,
    repeat: body.repeat ?? false,
  });
  return json(job, 201);
};

const deleteJob: Handler = async (_req, { scheduler }, params) => {
  const removed = await scheduler.removeJob(params.id);
  if (!removed) return err('Job not found', 404);
  return json({ success: true });
};

const patchJobToggle: Handler = async (_req, { scheduler }, params) => {
  const job = await scheduler.toggleJob(params.id);
  if (!job) return err('Job not found', 404);
  return json(job);
};

const getSoul: Handler = async (_req, { soul }) => {
  const content = await soul.read();
  return json({ content });
};

const putSoul: Handler = async (req, { soul }) => {
  const { content } = (await req.json()) as { content: string };
  if (!content) return err('content required', 400);
  await soul.save(content);
  return json({ success: true });
};

const postRegisterDevice: Handler = async (req) => {
  console.log("[API] postRegisterDevice called");
  const { token } = (await req.json()) as { token: string };
  if (!token) return err('token required', 400);
  await registerDevice(token);
  return json({ success: true });
};

const deleteRegisterDevice: Handler = async (req) => {
  const { token } = (await req.json()) as { token: string };
  if (!token) return err('token required', 400);
  await unregisterDevice(token);
  return json({ success: true });
};

const getModelList: Handler = async (_req, { agent }) => {
  const keys = detectApiKeys();
  const available = getAvailableModels(keys);
  const currentId = agent.getModelId();

  const models = available.map(m => ({
    id: m.id,
    label: m.label,
    preset: m.preset,
    vision: m.vision,
    toolUse: m.toolUse,
    current: m.id === currentId,
  }));

  return json({ models });
};

// ---------- Creations (OS) Handlers ----------

const getCreations: Handler = async () => {
  const creations = await listCreations();
  return json({ creations });
};

const getCreationById: Handler = async (_req, _ctx, params) => {
  const creation = await getCreation(params.id);
  if (!creation) return err('Creation not found', 404);
  return json(creation);
};

const getCreationPreviewHandler: Handler = async (_req, _ctx, params) => {
  const preview = await getCreationPreview(params.id);
  if (!preview) return err('Creation not found or not previewable', 404);
  return new Response(preview.content, {
    headers: { 'Content-Type': preview.mimeType },
  });
};

const deleteCreationHandler: Handler = async (_req, _ctx, params) => {
  const removed = await deleteCreation(params.id);
  if (!removed) return err('Creation not found', 404);
  return json({ success: true });
};


// ---------- Session Handlers ----------

const getSessions: Handler = async (_req, { sessions }) => {
  return json({ sessions: sessions.listSessions() });
};

const getSessionById: Handler = async (_req, { sessions }, params) => {
  const session = await sessions.getSession(params.id);
  if (!session) return err('Session not found', 404);
  return json({ session });
};

const postSession: Handler = async (req, { sessions }) => {
  const body = (await req.json()) as { source?: string; title?: string };
  const source = (body.source || 'api') as import('../sessions/types.js').SessionSource;
  const session = await sessions.createSession(source, body.title);
  return json({ id: session.id, title: session.title }, 201);
};

const deleteSessionById: Handler = async (_req, { sessions }, params) => {
  const removed = await sessions.deleteSession(params.id);
  if (!removed) return err('Session not found', 404);
  return json({ success: true });
};

const patchSession: Handler = async (req, { sessions }, params) => {
  const body = (await req.json()) as { title?: string };
  const meta = await sessions.updateSession(params.id, body);
  if (!meta) return err('Session not found', 404);
  return json(meta);
};

// ---------- Provider Keys Handlers ----------

const getKeys: Handler = async () => {
  const providers = await getProviderKeys();
  return json({ providers });
};

const putKey: Handler = async (req) => {
  const body = (await req.json()) as { provider: string; key: string };
  if (!body.provider || !body.key) return err('provider and key required', 400);
  try {
    await setProviderKey(body.provider, body.key);
    const providers = await getProviderKeys();
    return json({ providers });
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'Failed to set key';
    return err(msg, 400);
  }
};

const deleteKey: Handler = async (req) => {
  const body = (await req.json()) as { provider: string };
  if (!body.provider) return err('provider required', 400);
  try {
    await deleteProviderKey(body.provider);
    const providers = await getProviderKeys();
    return json({ providers });
  } catch (e) {
    const msg = e instanceof Error ? e.message : 'Failed to delete key';
    return err(msg, 400);
  }
};

const getMcpServerList: Handler = async () => {
  const servers = await getMcpServers();
  return json({ servers });
};

// ---------- Shopping List Handlers ----------

const SHOPPING_LIST_PATH = resolve(
  process.env.DATA_DIR || './data',
  'shopping-list.json',
);

const postShoppingList: Handler = async (req) => {
  const body = (await req.json()) as ShoppingListRequest;
  if (!body.listName || !body.items?.length) {
    return err('listName and items required', 400);
  }
  const dir = resolve(SHOPPING_LIST_PATH, '..');
  await mkdir(dir, { recursive: true });
  await writeFile(SHOPPING_LIST_PATH, JSON.stringify(body, null, 2));
  const resp: ShoppingListResponse = {
    success: true,
    listName: body.listName,
    itemCount: body.items.length,
  };
  return json(resp, 201);
};

const getShoppingList: Handler = async () => {
  try {
    const raw = await readFile(SHOPPING_LIST_PATH, 'utf-8');
    return json(JSON.parse(raw));
  } catch {
    return json({ listName: '', items: [] });
  }
};

// ---------- Commands (AI/Local) Handlers ----------

const getCommands: Handler = async () => {
  const commands = await loadCommands();
  return json({ commands });
};

const postCommandCreate: Handler = async (req) => {
  const body = (await req.json()) as Omit<StoredCommand, 'id' | 'createdAt'>;
  if (!body.name) return err('name required', 400);
  if (body.commandType === 'local' && !body.script) return err('script required for local commands', 400);
  if (body.commandType === 'ai' && !body.prompt) return err('prompt required for AI commands', 400);

  const commands = await loadCommands();
  const newCmd: StoredCommand = {
    id: crypto.randomUUID(),
    name: body.name,
    commandType: body.commandType || 'ai',
    prompt: body.prompt || '',
    script: body.script || '',
    outputMode: body.outputMode || 'clipboard',
    createdAt: new Date().toISOString(),
  };
  commands.push(newCmd);
  await saveCommands(commands);
  return json(newCmd, 201);
};

const deleteCommand: Handler = async (_req, _ctx, params) => {
  const commands = await loadCommands();
  const filtered = commands.filter(c => c.id !== params.id);
  if (filtered.length === commands.length) return err('Command not found', 404);
  await saveCommands(filtered);
  return json({ success: true });
};

// ---------- Router ----------

interface Route {
  method: string;
  pattern: RegExp;
  handler: Handler;
  paramNames: string[];
}

function route(method: string, path: string, handler: Handler): Route {
  const paramNames: string[] = [];
  const pattern = path.replace(/:(\w+)/g, (_m, name) => {
    paramNames.push(name);
    return '([^/]+)';
  });
  return {
    method,
    pattern: new RegExp('^' + pattern + '$'),
    handler,
    paramNames,
  };
}

const routes: Route[] = [
  route('POST', '/api/chat', postChat),
  route('POST', '/api/command', postCommand),
  route('GET', '/api/status', getStatus),
  route('GET', '/api/models', getModels),
  route('GET', '/api/models/list', getModelList),
  route('PUT', '/api/model', putModel),
  route('GET', '/api/memory/search', getMemorySearch),
  route('GET', '/api/memory/lines', getMemoryLines),
  route('GET', '/api/memory/recent', getMemoryRecent),
  route('GET', '/api/jobs', getJobs),
  route('POST', '/api/jobs', postJob),
  route('DELETE', '/api/jobs/:id', deleteJob),
  route('PATCH', '/api/jobs/:id/toggle', patchJobToggle),
  route('GET', '/api/soul', getSoul),
  route('PUT', '/api/soul', putSoul),
  route('POST', '/api/register-device', postRegisterDevice),
  route('DELETE', '/api/register-device', deleteRegisterDevice),
  route("GET", "/api/sessions", getSessions),
  route("POST", "/api/sessions", postSession),
  route("GET", "/api/sessions/:id", getSessionById),
  route("DELETE", "/api/sessions/:id", deleteSessionById),
  route("PATCH", "/api/sessions/:id", patchSession),
  route('GET', '/api/creations', getCreations),
  route('GET', '/api/creations/:id', getCreationById),
  route('GET', '/api/creations/:id/preview', getCreationPreviewHandler),
  route('DELETE', '/api/creations/:id', deleteCreationHandler),
  route('GET', '/api/keys', getKeys),
  route('PUT', '/api/keys', putKey),
  route('DELETE', '/api/keys', deleteKey),
  route('GET', '/api/integrations/mcp', getMcpServerList),
  route('POST', '/api/shopping-list', postShoppingList),
  route('GET', '/api/shopping-list', getShoppingList),
  route('GET', '/api/commands', getCommands),
  route('POST', '/api/commands', postCommandCreate),
  route('DELETE', '/api/commands/:id', deleteCommand),
];

export function handleRoute(
  req: Request,
  ctx: RouteContext,
): Promise<Response> {
  const url = new URL(req.url);
  const method = req.method;

  for (const r of routes) {
    if (r.method !== method) continue;
    const match = url.pathname.match(r.pattern);
    if (!match) continue;

    const params: Record<string, string> = {};
    r.paramNames.forEach((name, i) => {
      params[name] = match[i + 1];
    });
    return r.handler(req, ctx, params);
  }

  return Promise.resolve(err('Not found', 404));
}
