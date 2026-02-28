import { tool } from 'ai';
import { z } from 'zod';
import type { MemoryStore } from '../memory/store.js';

export function createMemoryRecall(memory: MemoryStore) {
  return tool({
    description:
      'Search the Second Brain knowledge base. Supports text search and ' +
      'tag filtering. Returns structured results with summaries. ' +
      'Use this to find saved knowledge entries (links, concepts, notes, quotes).',
    inputSchema: z.object({
      query: z.string().describe('Search query (semantic + keyword)'),
      tags: z.string().describe('Comma-separated tag filter, empty string for all'),
      maxResults: z.string().describe('Max results to return, default "8"'),
    }),
    execute: async ({ query, tags, maxResults }) => {
      const tagFilter = tags
        .split(',')
        .map(t => t.trim().toLowerCase())
        .filter(Boolean);
      const limit = parseInt(maxResults, 10) || 8;

      const results = await memory.searchKnowledge(
        query,
        tagFilter.length > 0 ? tagFilter : undefined,
        limit,
      );
      const allTags = memory.listTags();

      return {
        query,
        found: results.length,
        results: results.map(r => ({
          id: r.id,
          title: r.title,
          summary: r.summary,
          tags: r.tags,
          score: Math.round(r.score * 100) / 100,
          sourceType: r.sourceType,
          sourceUrl: r.sourceUrl,
          createdAt: r.createdAt,
        })),
        availableTags: allTags.slice(0, 30),
      };
    },
  });
}
