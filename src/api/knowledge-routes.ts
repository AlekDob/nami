import type { Agent } from '../agent/agent.js';
import type { ApiError } from './types.js';

type Handler = (
  req: Request,
  agent: Agent,
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

const getKnowledgeList: Handler = async (req, agent) => {
  const url = new URL(req.url);
  const q = url.searchParams.get('q') || undefined;
  const tags = url.searchParams.get('tags')?.split(',').filter(Boolean) || undefined;
  const limit = parseInt(url.searchParams.get('limit') || '50', 10);
  const offset = parseInt(url.searchParams.get('offset') || '0', 10);

  const result = agent.getMemoryStore().listKnowledge(q, tags, limit, offset);
  return json(result);
};

const getKnowledgeById: Handler = async (_req, agent, params) => {
  const entry = agent.getMemoryStore().getKnowledge(params.id);
  if (!entry) return err('Knowledge entry not found', 404);
  return json(entry);
};

const getKnowledgeGraph: Handler = async (req, agent) => {
  const url = new URL(req.url);
  const limit = parseInt(url.searchParams.get('limit') || '100', 10);
  const data = agent.getMemoryStore().getGraphData(limit);
  return json(data);
};

const patchKnowledgeTags: Handler = async (req, agent, params) => {
  const body = (await req.json()) as { add?: string[]; remove?: string[] };
  const store = agent.getMemoryStore();
  const entry = store.getKnowledge(params.id);
  if (!entry) return err('Knowledge entry not found', 404);

  await store.tagKnowledge(params.id, body.add || [], body.remove || []);
  const updated = store.getKnowledge(params.id);
  return json({ success: true, tags: updated?.tags || [] });
};

const getTagList: Handler = async (_req, agent) => {
  const tags = agent.getMemoryStore().listTagsWithCount();
  return json({ tags });
};

const patchTagRename: Handler = async (req, agent, params) => {
  const { newName } = (await req.json()) as { newName: string };
  if (!newName?.trim()) return err('newName required', 400);
  const ok = agent.getMemoryStore().renameTag(params.name, newName.trim());
  if (!ok) return err('Tag not found', 404);
  return json({ success: true });
};

const postTagMerge: Handler = async (req, agent) => {
  const { keep, merge } = (await req.json()) as { keep: string; merge: string };
  if (!keep || !merge) return err('keep and merge required', 400);
  const ok = agent.getMemoryStore().mergeTags(keep, merge);
  if (!ok) return err('One or both tags not found', 404);
  return json({ success: true });
};

const deleteTag: Handler = async (_req, agent, params) => {
  const ok = agent.getMemoryStore().deleteTag(params.name);
  if (!ok) return err('Tag not found', 404);
  return json({ success: true });
};

export interface KnowledgeRoute {
  method: string;
  path: string;
  handler: Handler;
}

export const knowledgeRoutes: KnowledgeRoute[] = [
  { method: 'GET', path: '/api/knowledge', handler: getKnowledgeList },
  { method: 'GET', path: '/api/knowledge/graph', handler: getKnowledgeGraph },
  { method: 'GET', path: '/api/knowledge/:id', handler: getKnowledgeById },
  { method: 'PATCH', path: '/api/knowledge/:id/tags', handler: patchKnowledgeTags },
  { method: 'GET', path: '/api/tags', handler: getTagList },
  { method: 'PATCH', path: '/api/tags/:name/rename', handler: patchTagRename },
  { method: 'POST', path: '/api/tags/merge', handler: postTagMerge },
  { method: 'DELETE', path: '/api/tags/:name', handler: deleteTag },
];
