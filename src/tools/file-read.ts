import { tool } from 'ai';
import { z } from 'zod';
import { resolve, normalize } from 'path';
import { readFile } from 'fs/promises';

const DATA_DIR = resolve(process.cwd(), 'data');

function isPathSafe(filePath: string): boolean {
  const resolved = resolve(DATA_DIR, filePath);
  return resolved.startsWith(DATA_DIR);
}

export const fileRead = tool({
  description: 'Read a file from the data/ directory',
  inputSchema: z.object({
    path: z.string().describe('Relative path within data/ directory'),
  }),
  execute: async ({ path }) => {
    if (!isPathSafe(path)) {
      return { exists: false, content: '', error: 'Path outside data/' };
    }
    const fullPath = resolve(DATA_DIR, normalize(path));
    try {
      const content = await readFile(fullPath, 'utf-8');
      return { exists: true, content };
    } catch {
      return { exists: false, content: '', error: 'File not found' };
    }
  },
});
