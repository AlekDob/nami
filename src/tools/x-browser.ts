import { tool } from 'ai';
import { z } from 'zod';
import { chromium, type Browser, type BrowserContext, type Page } from 'playwright';
import { resolve } from 'path';
import { existsSync } from 'fs';

// Brain: x-storage-state-login-pattern
const STORAGE_STATE_PATH = resolve(
  process.env.DATA_DIR || './data',
  'browser',
  'x-storage-state.json',
);

const USER_AGENT =
  'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) ' +
  'AppleWebKit/537.36 (KHTML, like Gecko) ' +
  'Chrome/131.0.0.0 Safari/537.36';

let browser: Browser | null = null;
let context: BrowserContext | null = null;
let page: Page | null = null;

async function ensureLoggedIn(): Promise<Page> {
  if (page && !page.isClosed()) return page;

  if (!existsSync(STORAGE_STATE_PATH)) {
    throw new Error(
      'X login required. Run: bun run src/tools/x-login.ts ' +
      'on a machine with a display, then copy ' +
      'data/browser/x-storage-state.json to the server.',
    );
  }

  browser = await chromium.launch({ headless: true });
  context = await browser.newContext({
    storageState: STORAGE_STATE_PATH,
    viewport: { width: 1280, height: 900 },
    userAgent: USER_AGENT,
    locale: 'en-US',
  });
  page = await context.newPage();

  await page.goto('https://x.com/home', {
    waitUntil: 'domcontentloaded',
  });
  await page.waitForTimeout(3000);

  const url = page.url();
  if (url.includes('/login') || url.includes('/i/flow')) {
    await closeBrowser();
    throw new Error(
      'X cookies expired. Re-run: bun run src/tools/x-login.ts',
    );
  }

  return page;
}

interface TweetData {
  text: string;
  author: string;
  handle: string;
  avatar: string;
  time: string;
  likes: string;
  retweets: string;
  replies: string;
  url: string;
  isVerified: boolean;
  images: string[];
}

async function scrapeTweets(p: Page): Promise<TweetData[]> {
  // Wait for tweets to render (X is an SPA, needs JS execution)
  try {
    await p.waitForSelector('article[data-testid="tweet"]', {
      timeout: 10_000,
    });
  } catch {
    // No tweets found — log debug info
    const debugUrl = p.url();
    const debugTitle = await p.title();
    const debugHtml = await p.evaluate(
      () => document.body?.innerText?.slice(0, 500) || '',
    );
    console.error(
      `[x-browser] No tweets found. URL: ${debugUrl}, ` +
      `Title: ${debugTitle}, Body: ${debugHtml.slice(0, 200)}`,
    );
    return [];
  }

  return p.evaluate(() => {
    const articles = document.querySelectorAll(
      'article[data-testid="tweet"]',
    );
    const results: TweetData[] = [];

    articles.forEach((article) => {
      const textEl = article.querySelector('[data-testid="tweetText"]');
      const text = textEl?.textContent?.trim() || '';

      const userLinks = article.querySelectorAll('a[href^="/"]');
      let author = '';
      let handle = '';
      let tweetUrl = '';

      userLinks.forEach((link) => {
        const href = link.getAttribute('href') || '';
        if (href.match(/^\/\w+$/) && !author) {
          handle = href.replace('/', '@');
        }
        if (href.match(/^\/\w+\/status\/\d+$/)) {
          tweetUrl = `https://x.com${href}`;
        }
      });

      const displayName = article.querySelector(
        '[data-testid="User-Name"]',
      );
      author = displayName?.textContent?.split('@')[0]?.trim() || '';

      const timeEl = article.querySelector('time');
      const time = timeEl?.getAttribute('datetime') || '';

      const avatar =
        article
          .querySelector('div[data-testid="Tweet-User-Avatar"] img')
          ?.getAttribute('src') || '';

      const isVerified = !!article.querySelector(
        'svg[aria-label*="erified"]',
      );

      const images = Array.from(
        article.querySelectorAll('[data-testid="tweetPhoto"] img'),
      )
        .map((img) => img.getAttribute('src') || '')
        .filter(Boolean);

      const likes =
        article
          .querySelector('[data-testid="like"]')
          ?.textContent?.trim() || '0';
      const retweets =
        article
          .querySelector('[data-testid="retweet"]')
          ?.textContent?.trim() || '0';
      const replies =
        article
          .querySelector('[data-testid="reply"]')
          ?.textContent?.trim() || '0';

      if (text) {
        results.push({
          text, author, handle, avatar, time,
          likes, retweets, replies,
          url: tweetUrl, isVerified, images,
        });
      }
    });

    return results;
  });
}

// --- Tools ---

export const xBrowseTimeline = tool({
  description:
    'Browse X/Twitter home timeline via browser. ' +
    'Returns recent tweets from the feed.',
  inputSchema: z.object({
    scrollCount: z
      .number()
      .default(2)
      .describe('How many times to scroll for more tweets (1-5)'),
  }),
  execute: async ({ scrollCount }) => {
    try {
      const p = await ensureLoggedIn();
      await p.goto('https://x.com/home', {
        waitUntil: 'domcontentloaded',
      });
      await p.waitForTimeout(3000);

      const scrolls = Math.min(Math.max(scrollCount, 1), 5);
      for (let i = 0; i < scrolls; i++) {
        await p.evaluate(() => window.scrollBy(0, window.innerHeight));
        await p.waitForTimeout(1500);
      }

      const tweets = await scrapeTweets(p);
      return { tweets, count: tweets.length, source: 'browser' };
    } catch (err) {
      return { error: err instanceof Error ? err.message : String(err) };
    }
  },
});

export const xBrowseProfile = tool({
  description:
    'Browse a specific X/Twitter profile and get their recent tweets.',
  inputSchema: z.object({
    handle: z
      .string()
      .describe('X handle without @ (e.g. "alekdobrohotov")'),
  }),
  execute: async ({ handle }) => {
    try {
      const p = await ensureLoggedIn();
      const clean = handle.replace(/^@/, '');
      await p.goto(`https://x.com/${clean}`, {
        waitUntil: 'domcontentloaded',
      });
      await p.waitForTimeout(3000);

      await p.evaluate(() => window.scrollBy(0, window.innerHeight));
      await p.waitForTimeout(1500);

      const tweets = await scrapeTweets(p);

      const bio = await p.evaluate(() => {
        const desc = document.querySelector(
          '[data-testid="UserDescription"]',
        );
        const followers = document.querySelector(
          'a[href$="/verified_followers"] span, ' +
          'a[href$="/followers"] span',
        );
        return {
          description: desc?.textContent?.trim() || '',
          followers: followers?.textContent?.trim() || '?',
        };
      });

      return {
        handle: clean, bio: bio.description,
        followers: bio.followers, tweets,
        count: tweets.length, source: 'browser',
      };
    } catch (err) {
      return { error: err instanceof Error ? err.message : String(err) };
    }
  },
});

export const xBrowseSearch = tool({
  description:
    'Search X/Twitter via browser. Returns tweets matching the query.',
  inputSchema: z.object({
    query: z.string().describe('Search query'),
    tab: z
      .enum(['top', 'latest', 'people'])
      .default('top')
      .describe('Search tab'),
  }),
  execute: async ({ query, tab }) => {
    try {
      const p = await ensureLoggedIn();
      const encoded = encodeURIComponent(query);
      const tabParam =
        tab === 'top' ? '' : `&f=${tab === 'latest' ? 'live' : tab}`;
      await p.goto(
        `https://x.com/search?q=${encoded}${tabParam}`,
        { waitUntil: 'domcontentloaded' },
      );
      await p.waitForTimeout(3000);

      await p.evaluate(() => window.scrollBy(0, window.innerHeight));
      await p.waitForTimeout(1500);

      const tweets = await scrapeTweets(p);
      return { query, tweets, count: tweets.length, source: 'browser' };
    } catch (err) {
      return { error: err instanceof Error ? err.message : String(err) };
    }
  },
});

export const xBrowseNotifications = tool({
  description:
    'Check X/Twitter notifications via browser (mentions, likes, etc.).',
  inputSchema: z.object({}),
  execute: async () => {
    try {
      const p = await ensureLoggedIn();
      await p.goto('https://x.com/notifications', {
        waitUntil: 'domcontentloaded',
      });
      await p.waitForTimeout(3000);

      const notifications = await p.evaluate(() => {
        const items = document.querySelectorAll(
          'article, [data-testid="cellInnerDiv"]',
        );
        const results: Array<{ text: string }> = [];

        items.forEach((item) => {
          const text = item.textContent?.trim() || '';
          if (text && text.length > 10) {
            results.push({ text: text.slice(0, 300) });
          }
        });

        return results.slice(0, 20);
      });

      return {
        notifications, count: notifications.length, source: 'browser',
      };
    } catch (err) {
      return { error: err instanceof Error ? err.message : String(err) };
    }
  },
});

export const xBrowsePost = tool({
  description:
    'Post a tweet via browser. Text only, no image support.',
  inputSchema: z.object({
    text: z.string().max(280).describe('Tweet text'),
  }),
  execute: async ({ text }) => {
    try {
      const p = await ensureLoggedIn();
      await p.goto('https://x.com/compose/tweet', {
        waitUntil: 'domcontentloaded',
      });
      await p.waitForTimeout(2000);

      const editor = p.locator('[data-testid="tweetTextarea_0"]');
      await editor.waitFor({ timeout: 10000 });
      await editor.fill(text);
      await p.waitForTimeout(500);

      await p.locator('[data-testid="tweetButton"]').click();
      await p.waitForTimeout(3000);

      return { success: true, text, source: 'browser' };
    } catch (err) {
      return { error: err instanceof Error ? err.message : String(err) };
    }
  },
});

export const xBrowseReply = tool({
  description:
    'Reply to a tweet via browser. ' +
    'Navigate to the tweet URL and post a reply.',
  inputSchema: z.object({
    tweetUrl: z.string().url().describe('Full tweet URL'),
    text: z.string().max(280).describe('Reply text'),
  }),
  execute: async ({ tweetUrl, text }) => {
    try {
      const p = await ensureLoggedIn();
      await p.goto(tweetUrl, { waitUntil: 'domcontentloaded' });
      await p.waitForTimeout(3000);

      const replyBox = p.locator('[data-testid="tweetTextarea_0"]');
      await replyBox.waitFor({ timeout: 10000 });
      await replyBox.fill(text);
      await p.waitForTimeout(500);

      await p.locator('[data-testid="tweetButton"]').click();
      await p.waitForTimeout(3000);

      return { success: true, replyTo: tweetUrl, text, source: 'browser' };
    } catch (err) {
      return { error: err instanceof Error ? err.message : String(err) };
    }
  },
});

/** Gracefully close the browser session */
export async function closeBrowser(): Promise<void> {
  if (context) {
    await context.close();
    context = null;
    page = null;
  }
  if (browser) {
    await browser.close();
    browser = null;
  }
}
