import { z } from 'zod';
import { tool } from 'ai';
import { readFile, writeFile, mkdir } from 'fs/promises';
import { resolve } from 'path';

const COMMANDS_PATH = resolve(
  process.env.DATA_DIR || './data',
  'commands.json',
);

export interface StoredCommand {
  id: string;
  name: string;
  commandType: 'ai' | 'local';
  prompt: string;
  script: string;
  outputMode: 'clipboard' | 'panel' | 'chat';
  createdAt: string;
}

export async function loadCommands(): Promise<StoredCommand[]> {
  try {
    const raw = await readFile(COMMANDS_PATH, 'utf-8');
    return JSON.parse(raw);
  } catch {
    return [];
  }
}

export async function saveCommands(commands: StoredCommand[]): Promise<void> {
  const dir = resolve(COMMANDS_PATH, '..');
  await mkdir(dir, { recursive: true });
  await writeFile(COMMANDS_PATH, JSON.stringify(commands, null, 2));
}

/**
 * Tool: createLocalCommand
 * Allows Nami to create local bash commands for the user's NamiOS app.
 * The client syncs these via GET /api/commands.
 */
export const createLocalCommand = tool({
  description:
    'Create a local shell command for the user\'s NamiOS app. ' +
    'The command runs bash locally on the Mac — no AI API call needed. ' +
    'Use $NAMI_INPUT in the script to reference the user\'s selected text. ' +
    'Examples: word count, uppercase, JSON pretty-print, URL encode, open in Terminal.',
  inputSchema: z.object({
    name: z.string().describe('Human-readable command name, e.g. "Word Count"'),
    script: z.string().describe('Bash script. Use $NAMI_INPUT for selected text input.'),
    outputMode: z
      .enum(['clipboard', 'panel', 'chat'])
      .describe('Where the result goes: clipboard (copy), panel (floating window), chat (send to chat)'),
  }),
  execute: async ({ name, script, outputMode }) => {
    const commands = await loadCommands();
    const id = crypto.randomUUID();
    const newCmd: StoredCommand = {
      id,
      name,
      commandType: 'local',
      prompt: '',
      script,
      outputMode,
      createdAt: new Date().toISOString(),
    };
    commands.push(newCmd);
    await saveCommands(commands);
    return `Created local command "${name}" (id: ${id}). The user's NamiOS app will sync it automatically.`;
  },
});

/**
 * Tool: createAICommand
 * Allows Nami to create AI-powered commands for the user's NamiOS app.
 */
export const createAICommand = tool({
  description:
    'Create an AI-powered command for the user\'s NamiOS app. ' +
    'The command sends a prompt to the AI API with the selected text. ' +
    'Use {input} in the prompt template where the selected text should be inserted.',
  inputSchema: z.object({
    name: z.string().describe('Human-readable command name, e.g. "Translate to Spanish"'),
    prompt: z.string().describe('Prompt template. Use {input} for the selected text.'),
    outputMode: z
      .enum(['clipboard', 'panel', 'chat'])
      .describe('Where the result goes: clipboard (copy), panel (floating window), chat (send to chat)'),
  }),
  execute: async ({ name, prompt, outputMode }) => {
    const commands = await loadCommands();
    const id = crypto.randomUUID();
    const newCmd: StoredCommand = {
      id,
      name,
      commandType: 'ai',
      prompt,
      script: '',
      outputMode,
      createdAt: new Date().toISOString(),
    };
    commands.push(newCmd);
    await saveCommands(commands);
    return `Created AI command "${name}" (id: ${id}). The user's NamiOS app will sync it automatically.`;
  },
});

// REST helpers (loadCommands, saveCommands) already exported above
