import { tool } from 'ai';
import { z } from 'zod';
import { chromium, type BrowserContext, type Page } from 'playwright';
import { resolve } from 'path';

const BROWSER_DATA_DIR = resolve(
  process.env.DATA_DIR || './data',
  'browser',
  'x-session',
);

let context: BrowserContext | null = null;
let page: Page | null = null;

async function ensureLoggedIn(): Promise<Page> {
  if (page && !page.isClosed()) {
    return page;
  }

  const browser = await chromium.launchPersistentContext(
    BROWSER_DATA_DIR,
    {
      headless: true,
      viewport: { width: 1280, height: 900 },
      userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) ' +
        'AppleWebKit/537.36 (KHTML, like Gecko) ' +
        'Chrome/131.0.0.0 Safari/537.36',
      locale: 'en-US',
    },
  );

  context = browser;
  page = browser.pages()[0] || (await browser.newPage());

  await page.goto('https://x.com/home', { waitUntil: 'domcontentloaded' });
  await page.waitForTimeout(2000);

  const url = page.url();
  const needsLogin = url.includes('/login') || url.includes('/i/flow/login');

  if (needsLogin) {
    const username = process.env.X_USERNAME;
    const password = process.env.X_PASSWORD;

    if (!username || !password) {
      throw new Error(
        'X_USERNAME and X_PASSWORD required for first login. ' +
        'Set them in .env and restart.',
      );
    }

    await doLogin(page, username, password);
  }

  return page;
}

async function doLogin(
  p: Page,
  username: string,
  password: string,
): Promise<void> {
  await p.goto('https://x.com/i/flow/login', {
    waitUntil: 'domcontentloaded',
  });
  await p.waitForTimeout(2000);

  // Step 1: username
  const usernameInput = p.locator('input[autocomplete="username"]');
  await usernameInput.waitFor({ timeout: 10000 });
  await usernameInput.fill(username);
  await p.locator('[role="button"]:has-text("Next")').click();
  await p.waitForTimeout(2000);

  // Step 1b: sometimes X asks for email/phone verification
  const unusual = p.locator('input[data-testid="ocfEnterTextTextInput"]');
  if (await unusual.isVisible({ timeout: 3000 }).catch(() => false)) {
    // X is asking for additional verification (email or phone)
    const email = process.env.X_EMAIL || username;
    await unusual.fill(email);
    await p.locator('[data-testid="ocfEnterTextNextButton"]').click();
    await p.waitForTimeout(2000);
  }

  // Step 2: password
  const passwordInput = p.locator('input[type="password"]');
  await passwordInput.waitFor({ timeout: 10000 });
  await passwordInput.fill(password);
  await p.locator('[data-testid="LoginForm_Login_Button"]').click();
  await p.waitForTimeout(3000);

  // Verify login succeeded
  const afterUrl = p.url();
  if (afterUrl.includes('/login') || afterUrl.includes('/i/flow')) {
    throw new Error(
      'Login failed — X may require CAPTCHA or 2FA. ' +
      'Try logging in manually once in a non-headless browser.',
    );
  }
}

interface TweetData {
  text: string;
  author: string;
  handle: string;
  time: string;
  likes: string;
  retweets: string;
  replies: string;
  url: string;
}

async function scrapeTweets(p: Page): Promise<TweetData[]> {
  await p.waitForTimeout(2000);

  return p.evaluate(() => {
    const articles = document.querySelectorAll('article[data-testid="tweet"]');
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
          text,
          author,
          handle,
          time,
          likes,
          retweets,
          replies,
          url: tweetUrl,
        });
      }
    });

    return results;
  });
}

// --- Tools ---

export const xBrowseTimeline = tool({
  description:
    'Browse X/Twitter home timeline via browser (no API limits). ' +
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
      await p.goto('https://x.com/home', { waitUntil: 'domcontentloaded' });
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

      // Scroll once for more tweets
      await p.evaluate(() => window.scrollBy(0, window.innerHeight));
      await p.waitForTimeout(1500);

      const tweets = await scrapeTweets(p);

      // Get follower count
      const bio = await p.evaluate(() => {
        const desc = document.querySelector(
          '[data-testid="UserDescription"]',
        );
        const followers = document.querySelector(
          'a[href$="/verified_followers"] span, a[href$="/followers"] span',
        );
        return {
          description: desc?.textContent?.trim() || '',
          followers: followers?.textContent?.trim() || '?',
        };
      });

      return {
        handle: clean,
        bio: bio.description,
        followers: bio.followers,
        tweets,
        count: tweets.length,
        source: 'browser',
      };
    } catch (err) {
      return { error: err instanceof Error ? err.message : String(err) };
    }
  },
});

export const xBrowseSearch = tool({
  description:
    'Search X/Twitter via browser (no API limits). ' +
    'Returns tweets matching the query.',
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
      const tabParam = tab === 'top' ? '' : `&f=${tab === 'latest' ? 'live' : tab}`;
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
        notifications,
        count: notifications.length,
        source: 'browser',
      };
    } catch (err) {
      return { error: err instanceof Error ? err.message : String(err) };
    }
  },
});

export const xBrowsePost = tool({
  description:
    'Post a tweet via browser (no API limits). ' +
    'Text only, no image support.',
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
    'Reply to a tweet via browser (no API limits). ' +
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
}
