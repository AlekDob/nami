import type { SearchResult } from '../memory/types.js';
import type { Job } from '../scheduler/types.js';

// ---------- REST ----------

// ---------- Multimodal ----------

export type TextPart = { type: "text"; text: string };
export type ImagePart = { type: "image"; image: string };
export type MessageContent = string | Array<TextPart | ImagePart>;

export interface ChatRequest {
  messages: Array<{ role: 'user' | 'assistant'; content: MessageContent }>;
  sessionId?: string;
}

export interface ChatResponse {
  text: string;
  sessionId?: string;
  stats: {
    model: string;
    inputTokens: number;
    outputTokens: number;
    durationMs: number;
  };
  toolsUsed?: string[];
}

export interface MemorySearchResponse {
  query: string;
  results: SearchResult[];
}

export interface MemoryLinesResponse {
  path: string;
  from: number;
  count: number;
  text: string;
}

export interface JobCreateRequest {
  name: string;
  cron: string;
  task: string;
  userId?: string;
  repeat?: boolean;
  notify?: boolean;
}

export interface StatusResponse {
  uptime: number;
  model: string;
  memory: { rss: number; heap: number };
  channels: string[];
}

export interface ApiError {
  error: string;
  code: number;
}

// ---------- WebSocket ----------

export type WsClientMessage =
  | { type: 'chat'; messages: ChatRequest['messages']; sessionId?: string }
  | { type: 'ping' };

export type WsServerMessage =
  | { type: 'done'; text: string; stats: ChatResponse['stats']; sessionId?: string }
  | { type: 'error'; error: string }
  | { type: 'pong' }
  | { type: 'notification'; title: string; body: string }
  | { type: "tool_use"; tool: string }
  | { type: "creation"; id: string; name: string; creationType: string }
  | { type: "shopping_list"; listName: string; items: ShoppingListItem[] };

// ---------- Shopping List ----------

export interface ShoppingListItem {
  title: string;
  notes: string;
}

export interface ShoppingListRequest {
  listName: string;
  items: ShoppingListItem[];
}

export interface ShoppingListResponse {
  success: boolean;
  listName: string;
  itemCount: number;
}

// Re-export for convenience
export type { SearchResult, Job };

export interface MemoryRecentResponse {
  results: SearchResult[];
}

// ---------- Provider Keys ----------

export interface ProviderKeyStatus {
  id: string;
  label: string;
  configured: boolean;
  maskedKey?: string;
}

export interface ProviderKeysResponse {
  providers: ProviderKeyStatus[];
}

export interface SetKeyRequest {
  provider: string;
  key: string;
}

export interface DeleteKeyRequest {
  provider: string;
}

// ---------- Integrations ----------

export interface MCPServerInfo {
  name: string;
  status: string;
}

export interface MCPServersResponse {
  servers: MCPServerInfo[];
}

// ---------- AI Command (lightweight prompt execution) ----------

export interface CommandRequest {
  prompt: string;
}

export interface CommandResponse {
  result: string;
  stats: {
    model: string;
    durationMs: number;
  };
}
