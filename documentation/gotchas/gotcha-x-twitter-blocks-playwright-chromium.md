---
type: gotcha
project: namios
created: 2026-02-18
last_verified: 2026-02-18
tags: [x-twitter, playwright, chromium, bot-detection, authentication]
---

# X/Twitter Blocks Playwright Chromium Login

## Symptom

Playwright opens `x.com/login`, user enters credentials manually in headed mode, X returns:

> "Could not log you in now. Please try again later."
> `g;1771407913379044487:-1771407916201:ii4U6OKR4bYRlte057I23xlf:1`

Login works fine in real browser (Dia, Chrome, Safari) with same credentials.

## Root Cause

X performs **browser fingerprinting** that detects Playwright's Chromium:

- Playwright Chromium has a distinct browser fingerprint (WebGL, canvas, navigator properties)
- Even with `headless: false`, Playwright injects automation markers
- `channel: "chrome"` (real Chrome via Playwright) may also be detected
- X is among the most aggressive bot detectors — stricter than Reddit, LinkedIn, etc.

## Why Reddit Works But X Doesn't

| Feature | Reddit | X/Twitter |
|---------|--------|-----------|
| Anonymous read | `.json` endpoints, no auth | No public API, SPA-only |
| Playwright login | Works (less strict detection) | Blocked (aggressive fingerprinting) |
| Guest API | N/A | Killed in 2023 |
| Nitter/alt frontend | N/A | 3 fragile instances, frequently blocked |
| API pricing | Free (anonymous) | $100/mo (Basic) |

## Solution

Don't log in via Playwright. Instead, extract cookies from a real browser:

1. User logs in to X on their real browser (Dia, Chrome, etc.)
2. Script reads cookies directly from Chromium's SQLite database
3. Decrypts with macOS Keychain key
4. Exports as Playwright `storageState` JSON
5. Server loads cookies — Playwright operates as authenticated session

See: `patterns/pattern-chromium-cookie-extraction-bun-sqlite.md`

## Key Insight

The login is the bottleneck, not the scraping. Once you have valid cookies, Playwright can browse X freely — the ongoing requests don't trigger the same level of bot detection as the login flow.

## Related

- `src/tools/x-login.ts` — cookie extraction script
- `src/tools/x-browser.ts` — uses storageState to bypass login
