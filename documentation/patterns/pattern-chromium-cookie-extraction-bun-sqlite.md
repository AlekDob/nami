---
type: pattern
project: namios
created: 2026-02-18
last_verified: 2026-02-18
tags: [chromium, cookies, bun, sqlite, authentication, x-twitter]
---

# Chromium Cookie Extraction with bun:sqlite

Extract encrypted cookies from any Chromium-based browser (Dia, Chrome, Brave, Edge) on macOS using pure Bun — no Python or external dependencies.

## When to Use

- You need authenticated browser cookies for server-side scraping
- The target site blocks Playwright/headless login (CAPTCHA, 2FA, bot detection)
- You want to reuse a real browser session on a headless server
- Same pattern as AWS Cognito token extraction, but for cookie-based auth

## How It Works

1. **Cookie DB**: Chromium stores cookies in SQLite at `~/Library/Application Support/{Browser}/User Data/Default/Cookies`
2. **Encryption**: macOS encrypts cookie values with AES-128-CBC, key derived from Keychain
3. **Keychain**: Each browser has a named entry (e.g. `"Dia Safe Storage"`, `"Chrome Safe Storage"`)
4. **Extraction**: Copy DB → derive key → decrypt cookies → export as Playwright `storageState` JSON

## Browser Paths (macOS)

| Browser | DB Path | Keychain Service |
|---------|---------|-----------------|
| Dia | `Dia/User Data/Default/Cookies` | `Dia Safe Storage` |
| Chrome | `Google/Chrome/Default/Cookies` | `Chrome Safe Storage` |
| Brave | `BraveSoftware/Brave-Browser/Default/Cookies` | `Brave Safe Storage` |
| Edge | `Microsoft Edge/Default/Cookies` | `Microsoft Edge Safe Storage` |

All under `~/Library/Application Support/`.

## Implementation

```typescript
import { Database } from 'bun:sqlite';
import { execSync } from 'child_process';
import { pbkdf2Sync, createDecipheriv } from 'crypto';
import { copyFileSync, unlinkSync } from 'fs';

// 1. Get encryption key from Keychain
const keyRaw = execSync(
  'security find-generic-password -s "Dia Safe Storage" -w'
).toString().trim();
const key = pbkdf2Sync(keyRaw, 'saltysalt', 1003, 16, 'sha1');

// 2. Copy DB (browser may lock it)
copyFileSync(dbPath, tmpPath);

// 3. Query cookies
const db = new Database(tmpPath, { readonly: true });
const rows = db.query(
  "SELECT name, encrypted_value, host_key, path, expires_utc, " +
  "is_httponly, is_secure, samesite FROM cookies " +
  "WHERE host_key = '.x.com' OR host_key = '.twitter.com'"
).all();

// 4. Decrypt — strip first-block garbage (see gotcha-chromium-aes-first-block-garbage.md)
function decrypt(enc: Uint8Array): string {
  const buf = Buffer.alloc(enc.length);
  for (let i = 0; i < enc.length; i++) buf[i] = enc[i]; // safe copy
  if (buf.slice(0, 3).toString('ascii') === 'v10') {
    const iv = Buffer.alloc(16, ' ');
    const decipher = createDecipheriv('aes-128-cbc', key, iv);
    const str = Buffer.concat([
      decipher.update(buf.slice(3)), decipher.final()
    ]).toString('utf-8');
    // Strip AES first-block garbage (16 bytes → ~27 UTF-8 chars)
    for (let i = 0; i < str.length; i++) {
      if ([...str.slice(i)].every(c => c.charCodeAt(0) >= 32 && c.charCodeAt(0) < 127)) {
        return str.slice(i);
      }
    }
    return str;
  }
  return buf.toString('utf-8');
}

// 5. Export as Playwright storageState
const storageState = {
  cookies: rows.map(r => ({
    name: r.name,
    value: decrypt(r.encrypted_value),
    domain: r.host_key,
    path: r.path,
    expires: r.expires_utc / 1e6 - 11644473600, // Chrome epoch → Unix
    httpOnly: Boolean(r.is_httponly),
    secure: Boolean(r.is_secure),
    sameSite: { 0: 'None', 1: 'Lax', 2: 'Strict' }[r.samesite] || 'None',
  })),
  origins: [],
};
```

## Gotchas

1. **Copy the DB first** — the browser keeps it locked while running
2. **Chrome epoch** is Jan 1, 1601 — offset by 11644473600 seconds from Unix epoch
3. **v10 prefix** indicates AES-128-CBC encryption; older cookies may be unencrypted
4. **IV is 16 spaces** (`Buffer.alloc(16, ' ')`) — documented for all Chromium browsers on macOS, but in practice the first AES block (16 bytes) may decrypt to garbage. Strip leading non-printable chars from the result — cookie values are always printable ASCII
5. **First-block garbage**: AES-CBC XORs the first plaintext block with the IV. If the actual IV differs (some Chromium versions/builds), only the first 16 bytes are corrupted (27 UTF-8 chars). The rest decrypts correctly. Safe to strip.
6. **Cookie lifetime** ~30 days for session cookies, longer for persistent ones
7. **PBKDF2 params**: SHA-1, 1003 iterations, 16-byte key — same for all Chromium on macOS
8. **expires: -1** means session cookie — Playwright may reject this in `storageState`. Keep as `-1` (Playwright accepts it) or use a far-future timestamp

## NamiOS Usage

- **Script**: `src/tools/x-login.ts` — extracts X.com cookies from Dia
- **Consumer**: `src/tools/x-browser.ts` — loads cookies via `storageState` in Playwright
- **Storage**: `data/browser/x-storage-state.json`
- **Refresh**: re-run `bun run src/tools/x-login.ts` on Mac when cookies expire

## Related

- `documentation/patterns/pattern-mac-remote-access-tailscale-agent.md` — Mac proxy access
- AWS Cognito OTP pattern in `memory/cognito-otp-localstorage-extraction.md`
