import { tool } from 'ai';
import { z } from 'zod';
import { resolve, normalize, dirname } from 'path';
import { writeFile, readFile, mkdir } from 'fs/promises';

const DATA_DIR = resolve(process.cwd(), 'data');

function isPathSafe(filePath: string): boolean {
  const resolved = resolve(DATA_DIR, filePath);
  return resolved.startsWith(DATA_DIR);
}

/** Parse markdown into a Map of heading -> body */
function parseSections(content: string): Map<string, string> {
  const sections = new Map<string, string>();
  const lines = content.split('\n');
  let currentHeading = '__preamble__';
  let currentBody: string[] = [];

  for (const line of lines) {
    if (/^#{1,3}\s/.test(line)) {
      const body = currentBody.join('\n').trim();
      if (body || currentHeading !== '__preamble__') {
        sections.set(currentHeading, body);
      }
      currentHeading = line;
      currentBody = [];
    } else {
      currentBody.push(line);
    }
  }
  const body = currentBody.join('\n').trim();
  if (body || currentHeading !== '__preamble__') {
    sections.set(currentHeading, body);
  }

  return sections;
}

/** Merge new MEMORY.md content with existing, preserving sections */
async function mergeMemory(
  fullPath: string,
  newContent: string,
): Promise<string> {
  let existing = '';
  try {
    existing = await readFile(fullPath, 'utf-8');
  } catch {
    return newContent;
  }

  if (!existing.trim()) return newContent;

  const existingSections = parseSections(existing);
  const newSections = parseSections(newContent);

  for (const [heading, sectionBody] of newSections) {
    existingSections.set(heading, sectionBody);
  }

  const parts: string[] = [];
  for (const [heading, sectionBody] of existingSections) {
    if (heading === '__preamble__') {
      parts.push(sectionBody);
    } else {
      parts.push(`${heading}\n${sectionBody}`);
    }
  }
  return parts.join('\n\n').trim() + '\n';
}

function isMemoryFile(path: string): boolean {
  const norm = normalize(path).toLowerCase();
  return norm.endsWith('memory.md');
}

export const fileWrite = tool({
  description:
    'Write content to a file in the data/ directory. ' +
    'For MEMORY.md, content is merged with existing sections automatically.',
  inputSchema: z.object({
    path: z.string().describe('Relative path within data/ directory'),
    content: z.string().describe('Content to write'),
  }),
  execute: async ({ path, content }) => {
    if (!isPathSafe(path)) {
      return { success: false, path: '', error: 'Path outside data/' };
    }
    const fullPath = resolve(DATA_DIR, normalize(path));
    try {
      await mkdir(dirname(fullPath), { recursive: true });

      const finalContent = isMemoryFile(path)
        ? await mergeMemory(fullPath, content)
        : content;

      await writeFile(fullPath, finalContent, 'utf-8');
      return { success: true, path: fullPath };
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return { success: false, path: fullPath, error: msg };
    }
  },
});
