import { tool } from 'ai';
import { z } from 'zod';
import { ImapFlow } from 'imapflow';

interface EmailConfig {
  host: string;
  port: number;
  user: string;
  password: string;
}

function getEmailConfig(): EmailConfig | null {
  const host = process.env.IMAP_HOST;
  const user = process.env.IMAP_USER;
  const password = process.env.IMAP_PASSWORD;
  if (!host || !user || !password) return null;
  return {
    host,
    port: parseInt(process.env.IMAP_PORT || '993', 10),
    user,
    password,
  };
}

export const emailRead = tool({
  description: 'Read emails from inbox via IMAP',
  inputSchema: z.object({
    folder: z.string().default('INBOX').describe('Mail folder'),
    limit: z.number().default(5).describe('Max emails to fetch'),
    unreadOnly: z.boolean().default(true).describe('Only unread'),
  }),
  execute: async ({ folder, limit, unreadOnly }) => {
    const config = getEmailConfig();
    if (!config) {
      return { error: 'IMAP not configured. Set IMAP_HOST, IMAP_USER, IMAP_PASSWORD.' };
    }

    const client = new ImapFlow({
      host: config.host,
      port: config.port,
      secure: true,
      auth: { user: config.user, pass: config.password },
      logger: false,
    });

    try {
      await client.connect();
      const lock = await client.getMailboxLock(folder);

      try {
        const query = unreadOnly ? { seen: false } : { all: true };
        const messages: Array<{
          from: string;
          subject: string;
          date: string;
          snippet: string;
        }> = [];

        let count = 0;
        for await (const msg of client.fetch(query, {
          envelope: true,
        })) {
          if (count >= limit) break;
          const env = msg.envelope ?? {};
          const from = (env as Record<string, unknown>).from as Array<{ address?: string }> | undefined;
          const subject = ((env as Record<string, unknown>).subject as string) || '(no subject)';
          const date = (env as Record<string, unknown>).date as Date | undefined;
          messages.push({
            from: from?.[0]?.address || 'unknown',
            subject,
            date: date?.toISOString() || '',
            snippet: subject.slice(0, 200),
          });
          count++;
        }
        return { folder, count: messages.length, messages };
      } finally {
        lock.release();
      }
    } catch (err) {
      const msg = err instanceof Error ? err.message : String(err);
      return { error: msg };
    } finally {
      await client.logout().catch(() => {});
    }
  },
});
