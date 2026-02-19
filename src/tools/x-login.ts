/**
 * X/Twitter cookie extractor — pure Bun, no Python needed.
 *
 * Reads X.com cookies directly from your Chromium browser's SQLite DB,
 * decrypts them using macOS Keychain, and saves as Playwright storageState.
 *
 * Supports: Dia, Chrome, Brave, Edge (auto-detects first available).
 *
 * Usage:
 *   bun run src/tools/x-login.ts
 *
 * After extraction, copy to server:
 *   scp data/browser/x-storage-state.json root@ubuntu-4gb-hel1-1:/root/meow/data/browser/
 */
import { Database } from 'bun:sqlite';
import { execSync } from 'child_process';
import { pbkdf2Sync, createDecipheriv } from 'crypto';
import { resolve, join } from 'path';
import {
  mkdirSync, copyFileSync, unlinkSync, existsSync,
} from 'fs';
import { writeFile } from 'fs/promises';
import { homedir, tmpdir } from 'os';

const DATA_DIR = resolve(process.env.DATA_DIR || './data', 'browser');
const STORAGE_STATE_PATH = resolve(DATA_DIR, 'x-storage-state.json');

// Brain: x-storage-state-login-pattern
const BROWSERS = [
  {
    name: 'Dia',
    dbPath: 'Library/Application Support/Dia/User Data/Default/Cookies',
    keychainService: 'Dia Safe Storage',
  },
  {
    name: 'Chrome',
    dbPath: 'Library/Application Support/Google/Chrome/Default/Cookies',
    keychainService: 'Chrome Safe Storage',
  },
  {
    name: 'Brave',
    dbPath: 'Library/Application Support/BraveSoftware/Brave-Browser/Default/Cookies',
    keychainService: 'Brave Safe Storage',
  },
  {
    name: 'Edge',
    dbPath: 'Library/Application Support/Microsoft Edge/Default/Cookies',
    keychainService: 'Microsoft Edge Safe Storage',
  },
];

type SameSite = 'Strict' | 'Lax' | 'None';
const SAMESITE_MAP: Record<number, SameSite> = {
  [-1]: 'None', 0: 'None', 1: 'Lax', 2: 'Strict',
};

interface CookieRow {
  name: string;
  encrypted_value: Uint8Array;
  host_key: string;
  path: string;
  expires_utc: number;
  is_httponly: number;
  is_secure: number;
  samesite: number;
}

function decryptCookie(enc: Uint8Array, key: Buffer): string {
  // Force a clean buffer copy — Bun's Buffer.from(Uint8Array) can
  // share the underlying ArrayBuffer with wrong byte boundaries.
  const buf = Buffer.alloc(enc.length);
  for (let i = 0; i < enc.length; i++) buf[i] = enc[i];

  // v10 prefix = AES-128-CBC encrypted (Chromium macOS)
  if (buf.length > 3 && buf.slice(0, 3).toString('ascii') === 'v10') {
    const iv = Buffer.alloc(16, ' ');
    const decipher = createDecipheriv('aes-128-cbc', key, iv);
    const raw = Buffer.concat([
      decipher.update(buf.slice(3)),
      decipher.final(),
    ]);
    const str = raw.toString('utf-8');

    // AES-CBC first block (16 bytes) decrypts to garbage when the
    // actual encryption IV differs from our static IV. The real
    // cookie value is always printable ASCII — find where it starts.
    for (let i = 0; i < str.length; i++) {
      const rest = str.slice(i);
      if ([...rest].every((c) => {
        const code = c.charCodeAt(0);
        return code >= 32 && code < 127;
      })) {
        return rest;
      }
    }
    return str; // Fallback — return as-is
  }

  // Unencrypted
  return buf.toString('utf-8');
}

async function main(): Promise<void> {
  const home = homedir();

  // Find first available browser
  const browser = BROWSERS.find((b) =>
    existsSync(resolve(home, b.dbPath)),
  );

  if (!browser) {
    console.error('No supported Chromium browser found.');
    console.error('Supported: Dia, Chrome, Brave, Edge');
    process.exit(1);
  }

  console.log(`Found ${browser.name} cookie database.`);
  console.log('Extracting X.com cookies...\n');

  // Get encryption key from macOS Keychain
  const keyRaw = execSync(
    `security find-generic-password -s "${browser.keychainService}" -w`,
  ).toString().trim();
  const key = pbkdf2Sync(keyRaw, 'saltysalt', 1003, 16, 'sha1');

  // Copy DB to temp file (browser may have it locked)
  const dbPath = resolve(home, browser.dbPath);
  const tmpPath = join(tmpdir(), `nami-cookie-extract-${Date.now()}.db`);
  copyFileSync(dbPath, tmpPath);

  const db = new Database(tmpPath, { readonly: true });
  const rows = db.query(
    `SELECT name, encrypted_value, host_key, path, expires_utc,
            is_httponly, is_secure, samesite
     FROM cookies
     WHERE host_key = '.x.com' OR host_key = 'x.com'
        OR host_key = '.twitter.com' OR host_key = 'twitter.com'`,
  ).all() as CookieRow[];
  db.close();
  unlinkSync(tmpPath);

  if (rows.length === 0) {
    console.error(
      `No X.com cookies found in ${browser.name}.`,
    );
    console.error('Are you logged into X on this browser?');
    process.exit(1);
  }

  // Chrome epoch: Jan 1, 1601 → convert to Unix epoch
  const CHROME_EPOCH_OFFSET = 11644473600;

  const cookies = rows.map((row) => {
    const expires = row.expires_utc > 0
      ? row.expires_utc / 1_000_000 - CHROME_EPOCH_OFFSET
      : -1;
    return {
      name: row.name,
      value: decryptCookie(row.encrypted_value, key),
      domain: row.host_key,
      path: row.path,
      expires,
      httpOnly: Boolean(row.is_httponly),
      secure: Boolean(row.is_secure),
      sameSite: SAMESITE_MAP[row.samesite] || 'None',
    };
  });

  const storageState = { cookies, origins: [] };

  mkdirSync(DATA_DIR, { recursive: true });
  await writeFile(
    STORAGE_STATE_PATH,
    JSON.stringify(storageState, null, 2),
  );

  console.log(`Extracted ${cookies.length} cookies from ${browser.name}.`);
  console.log(`Saved to: ${STORAGE_STATE_PATH}\n`);
  console.log('To deploy on the server:');
  console.log(
    `  scp "${STORAGE_STATE_PATH}" root@ubuntu-4gb-hel1-1:/root/meow/data/browser/`,
  );
}

main().catch((err) => {
  console.error('Fatal error:', err.message);
  process.exit(1);
});
