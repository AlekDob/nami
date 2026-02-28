import { tool } from 'ai';
import { z } from 'zod';
import type { MemoryStore } from '../memory/store.js';

export function createMemoryTag(memory: MemoryStore) {
  return tool({
    description:
      'Add or remove tags from a knowledge entry. ' +
      'Use memoryRecall first to find the entry ID.',
    inputSchema: z.object({
      knowledgeId: z.string().describe('Knowledge entry ID'),
      addTags: z.string().describe('Comma-separated tags to add, empty string to skip'),
      removeTags: z.string().describe('Comma-separated tags to remove, empty string to skip'),
    }),
    execute: async ({ knowledgeId, addTags, removeTags }) => {
      const add = addTags.split(',').map(t => t.trim().toLowerCase()).filter(Boolean);
      const remove = removeTags.split(',').map(t => t.trim().toLowerCase()).filter(Boolean);

      const entry = memory.getKnowledge(knowledgeId);
      if (!entry) {
        return { success: false, error: `Knowledge entry ${knowledgeId} not found` };
      }

      await memory.tagKnowledge(knowledgeId, add, remove);
      return { success: true, knowledgeId, added: add, removed: remove };
    },
  });
}
