export interface MemoryConfig {
  /** Max bytes for MEMORY.md in system prompt */
  memoryMaxBytes: number;
  /** Max daily log entries loaded in prompt */
  dailyTailCount: number;
  /** Hybrid search: vector weight (0-1) */
  vectorWeight: number;
  /** Hybrid search: keyword weight (0-1) */
  keywordWeight: number;
  /** Min score threshold for search results */
  minScore: number;
  /** Max search results returned */
  maxResults: number;
  /** Chunk size in chars for indexing */
  chunkSize: number;
  /** Chunk overlap in chars */
  chunkOverlap: number;
  /** Embedding provider: openai or none */
  embeddingProvider: 'openai' | 'none';
  /** Embedding model name */
  embeddingModel: string;
}

export const DEFAULT_MEMORY_CONFIG: MemoryConfig = {
  memoryMaxBytes: 4096,
  dailyTailCount: 10,
  vectorWeight: 0.7,
  keywordWeight: 0.3,
  minScore: 0.35,
  maxResults: 10,
  chunkSize: 1200,
  chunkOverlap: 200,
  embeddingProvider: process.env.MEMORY_EMBEDDINGS === 'true' ? 'openai' : 'none',
  embeddingModel: 'text-embedding-3-small',
};

export interface SearchResult {
  path: string;
  startLine: number;
  endLine: number;
  score: number;
  snippet: string;
  source: 'memory' | 'daily' | 'knowledge';
  knowledgeId?: string;
  tags?: string[];
}

export interface Chunk {
  id: string;
  path: string;
  startLine: number;
  endLine: number;
  text: string;
  hash: string;
}

export type SourceType = 'note' | 'link' | 'concept' | 'quote';

export interface KnowledgeEntry {
  id: string;
  title: string;
  content: string;
  summary: string;
  sourceUrl?: string;
  sourceType: SourceType;
  tags: string[];
  createdAt: string;
  updatedAt: string;
}

export interface KnowledgeResult {
  id: string;
  title: string;
  summary: string;
  tags: string[];
  score: number;
  sourceType: SourceType;
  sourceUrl?: string;
  createdAt: string;
}
