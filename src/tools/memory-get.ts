import { tool } from 'ai';
import { z } from 'zod';
import type { MemoryStore } from '../memory/store.js';

export function createMemoryGet(memory: MemoryStore) {
  return tool({
    description:
      'Read specific lines from a memory file after memory_search. ' +
      'Use this to get full context around a search result.',
    inputSchema: z.object({
      path: z.string().describe('Relative path from memory_search result'),
      from: z.number().describe('Starting line number'),
      lines: z.number().default(15).describe('Number of lines to read'),
    }),
    execute: async ({ path, from, lines }) => {
      const text = await memory.getLines(path, from, lines);
      return { path, from, lines, text };
    },
  });
}
