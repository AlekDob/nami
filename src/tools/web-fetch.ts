import { tool } from 'ai';
import { z } from 'zod';

export const webFetch = tool({
  description: 'Fetch content from a URL and return the text',
  inputSchema: z.object({
    url: z.string().url().describe('The URL to fetch'),
    maxLength: z.number()
      .optional()
      .default(10000)
      .describe('Max characters to return'),
  }),
  execute: async ({ url, maxLength }) => {
    const res = await fetch(url, {
      headers: { 'User-Agent': 'Meow/0.1' },
      signal: AbortSignal.timeout(15000),
    });
    const text = await res.text();
    return {
      content: text.slice(0, maxLength),
      status: res.status,
      contentType: res.headers.get('content-type') || 'unknown',
      truncated: text.length > maxLength,
    };
  },
});
