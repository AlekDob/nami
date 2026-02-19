export interface SessionMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: string;
}

export type SessionSource = 'ios' | 'macos' | 'discord' | 'cli' | 'api' | 'job';

export interface Session {
  id: string;
  title: string;
  source: SessionSource;
  messages: SessionMessage[];
  createdAt: string;
  updatedAt: string;
}

export interface SessionMeta {
  id: string;
  title: string;
  source: SessionSource;
  messageCount: number;
  createdAt: string;
  updatedAt: string;
  lastMessage: string;
}

export interface SessionIndex {
  sessions: SessionMeta[];
  version: number;
}
