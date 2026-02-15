import { tool } from 'ai';
import { z } from 'zod';

const REDDIT_BASE = 'https://www.reddit.com';
const USER_AGENT = 'NamiOS/0.1 (personal assistant)';
const REQUEST_TIMEOUT = 15_000;

interface RedditListing {
  kind: string;
  data: {
    children: Array<{ kind: string; data: Record<string, unknown> }>;
    after: string | null;
  };
}

interface RedditPost {
  title: string;
  author: string;
  subreddit: string;
  score: number;
  numComments: number;
  url: string;
  permalink: string;
  selftext: string;
  created: string;
  isNsfw: boolean;
}

async function redditFetch(
  path: string,
  params?: Record<string, string>,
): Promise<RedditListing> {
  const url = new URL(`${REDDIT_BASE}${path}.json`);
  url.searchParams.set('raw_json', '1');
  if (params) {
    for (const [k, v] of Object.entries(params)) {
      url.searchParams.set(k, v);
    }
  }

  const res = await fetch(url.toString(), {
    headers: { 'User-Agent': USER_AGENT },
    signal: AbortSignal.timeout(REQUEST_TIMEOUT),
  });

  if (res.status === 429) {
    throw new Error('Reddit rate limit hit. Try again in a few minutes.');
  }
  if (!res.ok) {
    throw new Error(`Reddit ${res.status}: ${await res.text()}`);
  }

  return res.json() as Promise<RedditListing>;
}

function parsePost(raw: Record<string, unknown>): RedditPost {
  return {
    title: String(raw.title || ''),
    author: String(raw.author || '[deleted]'),
    subreddit: String(raw.subreddit_prefixed || ''),
    score: Number(raw.score || 0),
    numComments: Number(raw.num_comments || 0),
    url: String(raw.url || ''),
    permalink: `https://www.reddit.com${raw.permalink || ''}`,
    selftext: String(raw.selftext || '').slice(0, 1000),
    created: new Date(Number(raw.created_utc || 0) * 1000).toISOString(),
    isNsfw: Boolean(raw.over_18),
  };
}

function parsePosts(listing: RedditListing): RedditPost[] {
  return listing.data.children
    .filter((c) => c.kind === 't3')
    .map((c) => parsePost(c.data));
}

// --- Tools ---

export const redditFeed = tool({
  description:
    'Browse Reddit front page, popular, or all feeds. ' +
    'Returns top posts sorted by hot/new/top/rising.',
  inputSchema: z.object({
    feed: z
      .string()
      .describe('Feed: "popular", "all", or "home" (default: popular)'),
    sort: z
      .string()
      .describe('Sort: "hot", "new", "top", "rising" (default: hot)'),
    time: z
      .string()
      .describe('Time for top sort: "hour","day","week","month","year","all" (default: day)'),
    limit: z
      .string()
      .describe('Number of posts: "10","25","50" (default: 25)'),
  }),
  execute: async ({ feed, sort, time, limit }) => {
    try {
      const base = feed === 'home' ? '' : `/r/${feed}`;
      const sortPath = sort === 'hot' ? '' : `/${sort}`;
      const listing = await redditFetch(
        `${base}${sortPath}`,
        { limit, t: time },
      );
      const posts = parsePosts(listing);
      return { feed, sort, posts, count: posts.length };
    } catch (err) {
      return { error: err instanceof Error ? err.message : String(err) };
    }
  },
});

export const redditSubreddit = tool({
  description:
    'Browse a specific subreddit. ' +
    'Returns posts with title, score, author, comments.',
  inputSchema: z.object({
    subreddit: z
      .string()
      .describe('Subreddit name without r/ (e.g. "technology")'),
    sort: z
      .string()
      .describe('Sort: "hot","new","top","rising" (default: hot)'),
    time: z
      .string()
      .describe('Time for top sort: "hour","day","week","month","year","all" (default: day)'),
    limit: z
      .string()
      .describe('Number of posts: "10","25","50" (default: 25)'),
  }),
  execute: async ({ subreddit, sort, time, limit }) => {
    try {
      const clean = subreddit.replace(/^r\//, '');
      const sortPath = sort === 'hot' ? '' : `/${sort}`;
      const listing = await redditFetch(
        `/r/${clean}${sortPath}`,
        { limit, t: time },
      );
      const posts = parsePosts(listing);
      return { subreddit: clean, sort, posts, count: posts.length };
    } catch (err) {
      return { error: err instanceof Error ? err.message : String(err) };
    }
  },
});

export const redditSearch = tool({
  description:
    'Search Reddit globally or within a subreddit. Returns matching posts.',
  inputSchema: z.object({
    query: z.string().describe('Search query'),
    subreddit: z
      .string()
      .describe('Limit to subreddit (empty string for global search)'),
    sort: z
      .string()
      .describe('Sort: "relevance","hot","top","new","comments" (default: relevance)'),
    time: z
      .string()
      .describe('Time range: "hour","day","week","month","year","all" (default: all)'),
    limit: z
      .string()
      .describe('Number of results: "10","25","50" (default: 25)'),
  }),
  execute: async ({ query, subreddit, sort, time, limit }) => {
    try {
      const path = subreddit ? `/r/${subreddit}/search` : '/search';
      const params: Record<string, string> = {
        q: query,
        sort,
        t: time,
        limit,
        restrict_sr: subreddit ? '1' : '0',
      };
      const listing = await redditFetch(path, params);
      const posts = parsePosts(listing);
      return { query, subreddit: subreddit || 'all', posts, count: posts.length };
    } catch (err) {
      return { error: err instanceof Error ? err.message : String(err) };
    }
  },
});

export const redditUser = tool({
  description:
    'View a Reddit user profile and their recent posts/comments.',
  inputSchema: z.object({
    username: z
      .string()
      .describe('Reddit username without u/ prefix'),
    type: z
      .string()
      .describe('Content: "overview","submitted","comments" (default: overview)'),
    limit: z
      .string()
      .describe('Number of items: "10","25" (default: 10)'),
  }),
  execute: async ({ username, type, limit }) => {
    try {
      const clean = username.replace(/^u\//, '');
      const listing = await redditFetch(
        `/user/${clean}/${type}`,
        { limit },
      );
      const items = listing.data.children.map((c) => {
        if (c.kind === 't3') return { type: 'post' as const, ...parsePost(c.data) };
        return {
          type: 'comment' as const,
          body: String(c.data.body || '').slice(0, 500),
          subreddit: String(c.data.subreddit_prefixed || ''),
          score: Number(c.data.score || 0),
          created: new Date(Number(c.data.created_utc || 0) * 1000).toISOString(),
          permalink: `https://www.reddit.com${c.data.permalink || ''}`,
        };
      });
      return { username: clean, items, count: items.length };
    } catch (err) {
      return { error: err instanceof Error ? err.message : String(err) };
    }
  },
});

export const redditPostComments = tool({
  description:
    'Read comments on a specific Reddit post. Returns top-level comments.',
  inputSchema: z.object({
    permalink: z
      .string()
      .describe('Post permalink path (e.g. "/r/technology/comments/abc123/title/")'),
    sort: z
      .string()
      .describe('Comment sort: "best","top","new","controversial" (default: best)'),
    limit: z
      .string()
      .describe('Number of comments: "10","25","50" (default: 25)'),
  }),
  execute: async ({ permalink, sort, limit }) => {
    try {
      const url = new URL(`${REDDIT_BASE}${permalink}.json`);
      url.searchParams.set('sort', sort);
      url.searchParams.set('limit', limit);
      url.searchParams.set('raw_json', '1');

      const res = await fetch(url.toString(), {
        headers: { 'User-Agent': USER_AGENT },
        signal: AbortSignal.timeout(REQUEST_TIMEOUT),
      });
      if (!res.ok) throw new Error(`Reddit ${res.status}`);

      const data = (await res.json()) as [RedditListing, RedditListing];
      const post = parsePosts(data[0])[0] || null;
      const comments = data[1].data.children
        .filter((c) => c.kind === 't1')
        .map((c) => ({
          author: String(c.data.author || '[deleted]'),
          body: String(c.data.body || '').slice(0, 500),
          score: Number(c.data.score || 0),
          created: new Date(
            Number(c.data.created_utc || 0) * 1000,
          ).toISOString(),
        }));

      return { post, comments, count: comments.length };
    } catch (err) {
      return { error: err instanceof Error ? err.message : String(err) };
    }
  },
});
