import { tool } from 'ai';
import { z } from 'zod';
import { chromium, type BrowserContext, type Page } from 'playwright';
import { resolve } from 'path';

const BROWSER_DATA_DIR = resolve(
  process.env.DATA_DIR || './data',
  'browser',
  'reddit-session',
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

  await page.goto('https://old.reddit.com', {
    waitUntil: 'domcontentloaded',
  });
  await page.waitForTimeout(2000);

  const loggedIn = await page
    .locator('span.user a')
    .first()
    .isVisible()
    .catch(() => false);

  if (!loggedIn) {
    const username = process.env.REDDIT_USERNAME;
    const password = process.env.REDDIT_PASSWORD;
    if (!username || !password) {
      throw new Error(
        'REDDIT_USERNAME and REDDIT_PASSWORD required for Reddit login. ' +
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
  await p.goto('https://old.reddit.com/login', {
    waitUntil: 'domcontentloaded',
  });
  await p.waitForTimeout(1000);

  await p.locator('#user_login').fill(username);
  await p.locator('#passwd_login').fill(password);
  await p.locator('#login-form button[type="submit"]').click();
  await p.waitForTimeout(3000);

  const userVisible = await p
    .locator('span.user a')
    .first()
    .isVisible()
    .catch(() => false);

  if (!userVisible) {
    throw new Error(
      'Reddit login failed. Check credentials or ' +
      'try logging in manually once in a non-headless browser.',
    );
  }
}

// --- Tools ---

export const redditPost = tool({
  description:
    'Create a new text post on a Reddit subreddit. ' +
    'Requires REDDIT_USERNAME and REDDIT_PASSWORD.',
  inputSchema: z.object({
    subreddit: z
      .string()
      .describe('Subreddit name without r/ (e.g. "test")'),
    title: z.string().describe('Post title'),
    body: z.string().describe('Post body text (markdown supported)'),
  }),
  execute: async ({ subreddit, title, body }) => {
    try {
      const p = await ensureLoggedIn();
      const clean = subreddit.replace(/^r\//, '');

      await p.goto(
        `https://old.reddit.com/r/${clean}/submit?selftext=true`,
        { waitUntil: 'domcontentloaded' },
      );
      await p.waitForTimeout(2000);

      await p.locator('input[name="title"]').fill(title);
      await p.locator('textarea[name="text"]').fill(body);
      await p.waitForTimeout(500);

      await p.locator('#newlink button[type="submit"]').click();
      await p.waitForTimeout(3000);

      const resultUrl = p.url();
      return {
        success: true,
        subreddit: clean,
        title,
        url: resultUrl,
        source: 'browser',
      };
    } catch (err) {
      return { error: err instanceof Error ? err.message : String(err) };
    }
  },
});

export const redditComment = tool({
  description:
    'Reply to a Reddit post or comment. ' +
    'Navigate to the permalink and post a reply.',
  inputSchema: z.object({
    permalink: z
      .string()
      .describe('Full Reddit URL of the post or comment to reply to'),
    text: z.string().describe('Comment text (markdown supported)'),
  }),
  execute: async ({ permalink, text }) => {
    try {
      const p = await ensureLoggedIn();
      const oldUrl = permalink.replace('www.reddit.com', 'old.reddit.com');

      await p.goto(oldUrl, { waitUntil: 'domcontentloaded' });
      await p.waitForTimeout(2000);

      const replyBox = p.locator('textarea[name="text"]').first();
      await replyBox.waitFor({ timeout: 10_000 });
      await replyBox.fill(text);
      await p.waitForTimeout(500);

      await p
        .locator('button[type="submit"]:has-text("save")')
        .first()
        .click();
      await p.waitForTimeout(3000);

      return { success: true, replyTo: permalink, text, source: 'browser' };
    } catch (err) {
      return { error: err instanceof Error ? err.message : String(err) };
    }
  },
});

export const redditMessages = tool({
  description:
    'Check Reddit inbox messages and notifications. Requires login.',
  inputSchema: z.object({
    type: z
      .string()
      .describe('Message type: "inbox", "unread", "sent" (default: unread)'),
  }),
  execute: async ({ type }) => {
    try {
      const p = await ensureLoggedIn();
      await p.goto(`https://old.reddit.com/message/${type}/`, {
        waitUntil: 'domcontentloaded',
      });
      await p.waitForTimeout(2000);

      const messages = await p.evaluate(() => {
        const items = document.querySelectorAll('.message');
        const results: Array<{
          from: string;
          subject: string;
          body: string;
          time: string;
        }> = [];

        items.forEach((item) => {
          results.push({
            from: item.querySelector('.author')?.textContent?.trim() || '',
            subject:
              item.querySelector('.subject a')?.textContent?.trim() || '',
            body: (
              item.querySelector('.md')?.textContent?.trim() || ''
            ).slice(0, 500),
            time:
              item.querySelector('time')?.getAttribute('datetime') || '',
          });
        });

        return results.slice(0, 20);
      });

      return { type, messages, count: messages.length, source: 'browser' };
    } catch (err) {
      return { error: err instanceof Error ? err.message : String(err) };
    }
  },
});

/** Gracefully close the Reddit browser session */
export async function closeRedditBrowser(): Promise<void> {
  if (context) {
    await context.close();
    context = null;
    page = null;
  }
}
