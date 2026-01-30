import type { MemoryConfig } from './types.js';

type EmbedFn = (text: string) => Promise<number[]>;

interface EmbeddingProvider {
  embed: EmbedFn;
  dimensions: number;
}

export function createEmbeddingProvider(
  config: MemoryConfig,
): EmbeddingProvider | null {
  if (config.embeddingProvider === 'none') return null;

  if (config.embeddingProvider === 'openai') {
    return createOpenAIProvider(config.embeddingModel);
  }

  return null;
}

function createOpenAIProvider(model: string): EmbeddingProvider | null {
  const apiKey = process.env.OPENAI_API_KEY;
  if (!apiKey) return null;

  const dimensions = model.includes('3-small') ? 1536 : 3072;

  return {
    dimensions,
    embed: async (text: string): Promise<number[]> => {
      const res = await fetch('https://api.openai.com/v1/embeddings', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${apiKey}`,
        },
        body: JSON.stringify({ input: text, model }),
      });

      if (!res.ok) {
        throw new Error(`OpenAI embedding error: ${res.status}`);
      }

      const data = await res.json() as {
        data: Array<{ embedding: number[] }>;
      };
      return data.data[0].embedding;
    },
  };
}
