import { tool } from 'ai';
import { z } from 'zod';
import { resolve, normalize } from 'path';
import { readFile } from 'fs/promises';

const PROJECT_ROOT = resolve(process.cwd());

export const fileRead = tool({
  description: 'Read a file. Path is relative to project root.',
  inputSchema: z.object({
    path: z.string().describe('Relative path from project root'),
  }),
  execute: async ({ path }) => {
    const fullPath = resolve(PROJECT_ROOT, normalize(path));
    try {
      const content = await readFile(fullPath, 'utf-8');
      return { exists: true, content };
    } catch {
      return { exists: false, content: '', error: 'File not found' };
    }
  },
});
