import { tool } from 'ai';
import { z } from 'zod';
import {
  xBrowseProfile,
  xBrowseSearch,
  xBrowseNotifications,
} from './x-browser.js';

const BASE_URL = 'https://api.twitter.com/2';

function getBearer(): string | null {
  return process.env.X_BEARER_TOKEN || null;
}

interface XResponse {
  data?: Array<Record<string, unknown>>;
  meta?: Record<string, unknown>;
}

/** Returns true if error looks like a rate/cap limit */
function isCapError(err: unknown): boolean {
  const msg = err instanceof Error ? err.message : String(err);
  return (
    msg.includes('429') ||
    msg.includes('UsageCapExceeded') ||
    msg.includes('Too Many Requests') ||
    msg.includes('Rate limit')
  );
}

async function xFetch(
  path: string,
  params?: Record<string, string>,
): Promise<XResponse> {
  const bearer = getBearer();
  if (!bearer) throw new Error('X_BEARER_TOKEN not configured');

  const url = new URL(`${BASE_URL}${path}`);
  if (params) {
    for (const [k, v] of Object.entries(params)) {
      url.searchParams.set(k, v);
    }
  }

  const res = await fetch(url.toString(), {
    headers: { Authorization: `Bearer ${bearer}` },
  });

  if (!res.ok) {
    const body = await res.text();
    throw new Error(`X API ${res.status}: ${body}`);
  }
  return res.json() as Promise<XResponse>;
}

export const xGetTimeline = tool({
  description:
    'Get recent tweets from a Twitter/X user. ' +
    'Falls back to browser scraping if API cap is hit.',
  inputSchema: z.object({
    userId: z.string().describe('X user ID (numeric) or handle'),
    maxResults: z.number().default(10).describe('Max tweets'),
  }),
  execute: async ({ userId, maxResults }) => {
    try {
      const data = await xFetch(`/users/${userId}/tweets`, {
        max_results: String(maxResults),
        'tweet.fields': 'created_at,public_metrics',
      });
      return {
        tweets: data.data || [],
        count: data.data?.length || 0,
        source: 'api',
      };
    } catch (err) {
      if (isCapError(err)) {
        // Fallback: use browser to scrape the profile
        const handle = userId.match(/^\d+$/)
          ? 'alekdobrohotov'
          : userId;
        return xBrowseProfile.execute(
          { handle },
          { toolCallId: '', messages: [], abortSignal: undefined as never },
        );
      }
      return { error: err instanceof Error ? err.message : String(err) };
    }
  },
});

export const xSearchTweets = tool({
  description:
    'Search tweets by keyword on Twitter/X. ' +
    'Falls back to browser search if API cap is hit.',
  inputSchema: z.object({
    query: z.string().describe('Search query'),
    maxResults: z.number().default(10).describe('Max results'),
  }),
  execute: async ({ query, maxResults }) => {
    try {
      const data = await xFetch('/tweets/search/recent', {
        query,
        max_results: String(maxResults),
        'tweet.fields': 'created_at,public_metrics,author_id',
      });
      return {
        tweets: data.data || [],
        count: data.data?.length || 0,
        source: 'api',
      };
    } catch (err) {
      if (isCapError(err)) {
        return xBrowseSearch.execute(
          { query, tab: 'top' },
          { toolCallId: '', messages: [], abortSignal: undefined as never },
        );
      }
      return { error: err instanceof Error ? err.message : String(err) };
    }
  },
});

export const xGetMentions = tool({
  description:
    'Get recent mentions/replies for a Twitter/X user. ' +
    'Falls back to browser notifications if API cap is hit.',
  inputSchema: z.object({
    userId: z.string().describe('X user ID (numeric)'),
    maxResults: z.number().default(10).describe('Max mentions'),
  }),
  execute: async ({ userId, maxResults }) => {
    try {
      const data = await xFetch(`/users/${userId}/mentions`, {
        max_results: String(maxResults),
        'tweet.fields': 'created_at,public_metrics,author_id',
      });
      return {
        mentions: data.data || [],
        count: data.data?.length || 0,
        source: 'api',
      };
    } catch (err) {
      if (isCapError(err)) {
        return xBrowseNotifications.execute(
          {},
          { toolCallId: '', messages: [], abortSignal: undefined as never },
        );
      }
      return { error: err instanceof Error ? err.message : String(err) };
    }
  },
});
