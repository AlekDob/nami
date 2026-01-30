import { generateText, stepCountIs, type ModelMessage } from 'ai';
import type { MemoryStore } from '../memory/store.js';

const FLUSH_SYSTEM = `You are performing a pre-compaction memory flush.
Review the conversation and save any important information to memory files.
- Save durable facts (user identity, preferences, decisions) to MEMORY.md using fileWrite
- Save today's events/tasks to daily notes using fileWrite
- If nothing important to save, respond with exactly: NO_REPLY`;

const FLUSH_PROMPT = `Review the conversation above. Save any important facts,
decisions, preferences, or context to the appropriate memory files using fileWrite.
If nothing new to save, respond with NO_REPLY.`;

const NO_REPLY = 'NO_REPLY';

interface FlushOptions {
  model: ReturnType<typeof import('ai').generateText> extends Promise<infer R> ? never : unknown;
  tools: Record<string, unknown>;
  messages: ModelMessage[];
}

/** Estimate token count from message array (rough: 4 chars = 1 token) */
export function estimateTokens(messages: ModelMessage[]): number {
  let chars = 0;
  for (const msg of messages) {
    if (typeof msg.content === 'string') {
      chars += msg.content.length;
    } else if (Array.isArray(msg.content)) {
      for (const part of msg.content) {
        if (typeof part === 'object' && 'text' in part) {
          chars += String(part.text).length;
        }
      }
    }
  }
  return Math.ceil(chars / 4);
}

/** Check if flush is needed based on conversation length */
export function shouldFlush(
  messages: ModelMessage[],
  contextWindow: number,
  threshold = 0.75,
): boolean {
  const used = estimateTokens(messages);
  return used >= contextWindow * threshold;
}

/**
 * Run a silent memory flush turn.
 * Returns true if the agent saved something, false if NO_REPLY.
 */
export async function runMemoryFlush(
  getModel: () => unknown,
  tools: Record<string, unknown>,
  messages: ModelMessage[],
): Promise<boolean> {
  const flushMessages: ModelMessage[] = [
    ...messages,
    { role: 'user', content: FLUSH_PROMPT },
  ];

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const result = await generateText({
    model: getModel() as any,
    system: FLUSH_SYSTEM,
    messages: flushMessages,
    tools: tools as any,
    stopWhen: stepCountIs(5),
  });

  return !result.text.includes(NO_REPLY);
}
