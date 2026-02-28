import { tool } from 'ai';
import { z } from 'zod';
import type { MemoryStore } from '../memory/store.js';
import type { SourceType } from '../memory/types.js';

export function createMemorySave(memory: MemoryStore) {
  return tool({
    description:
      'Save a piece of knowledge to the Second Brain. Use for facts, concepts, ' +
      'links, quotes, or anything worth remembering long-term. ' +
      'Auto-tag with 2-5 relevant lowercase tags.',
    inputSchema: z.object({
      title: z.string().describe('Short descriptive title (max 10 words)'),
      content: z.string().describe('Full content or notes'),
      summary: z.string().describe('One-line summary for quick recall (max 20 words)'),
      tags: z.string().describe('Comma-separated lowercase tags, e.g. "typescript,react,performance"'),
      sourceUrl: z.string().describe('Source URL if from a link, empty string otherwise'),
      sourceType: z.string().describe('Type: note | link | concept | quote'),
    }),
    execute: async ({ title, content, summary, tags, sourceUrl, sourceType }) => {
      const tagList = tags.split(',').map(t => t.trim().toLowerCase()).filter(Boolean);
      const validTypes: SourceType[] = ['note', 'link', 'concept', 'quote'];
      const type = validTypes.includes(sourceType as SourceType)
        ? (sourceType as SourceType)
        : 'note';

      const id = await memory.saveKnowledge({
        title,
        content,
        summary,
        tags: tagList,
        sourceUrl: sourceUrl || undefined,
        sourceType: type,
      });

      return { success: true, id, title, tags: tagList, sourceType: type };
    },
  });
}
