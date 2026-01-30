import { tool } from 'ai';
import { z } from 'zod';
import type { MemoryStore } from '../memory/store.js';

export function createMemorySearch(memory: MemoryStore) {
  return tool({
    description:
      'Search persistent memory. Use BEFORE answering questions about ' +
      'prior work, decisions, dates, people, preferences, or todos.',
    inputSchema: z.object({
      query: z.string().describe('Semantic search query'),
      maxResults: z.number().default(6).describe('Max results'),
    }),
    execute: async ({ query, maxResults }) => {
      const results = await memory.search(query);
      return {
        query,
        found: results.length,
        results: results.slice(0, maxResults).map(r => ({
          path: r.path,
          startLine: r.startLine,
          endLine: r.endLine,
          score: Math.round(r.score * 100) / 100,
          snippet: r.snippet,
          source: r.source,
        })),
      };
    },
  });
}
