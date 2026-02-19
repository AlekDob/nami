---
type: pattern
project: namios
created: 2026-02-13
tags: [node, bun, env, deployment, devops]
---

# Environment Variable Hot-Reload Without Restart

## Problem

Node/Bun load `process.env` once at startup from `.env` file. Changing `.env` requires full process restart, causing downtime.

## Solution

1. **Create reloadEnv() utility** — Re-parse `.env` file and update `process.env` in-place
2. **Dynamic env getters** — Replace top-level constants with functions that read `process.env` at call time
3. **API endpoint** — Expose `POST /api/reload-env` to trigger reload without restart

## Implementation

### 1. Reload Utility (`src/config/env.ts`)

```typescript
import { readFileSync } from 'fs';
import { resolve } from 'path';

const ENV_PATH = resolve('/root/meow/.env');

export function reloadEnv(): { updated: string[]; errors: string[] } {
  const updated: string[] = [];
  const errors: string[] = [];

  try {
    const content = readFileSync(ENV_PATH, 'utf-8');
    for (const line of content.split('\n')) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith('#')) continue;

      const eqIndex = trimmed.indexOf('=');
      if (eqIndex === -1) continue;

      const key = trimmed.slice(0, eqIndex).trim();
      let value = trimmed.slice(eqIndex + 1).trim();

      // Strip quotes
      if ((value.startsWith('"') && value.endsWith('"')) ||
          (value.startsWith("'") && value.endsWith("'"))) {
        value = value.slice(1, -1);
      }

      const old = process.env[key];
      process.env[key] = value;
      if (old !== value) updated.push(key);
    }
  } catch (e) {
    errors.push((e as Error).message);
  }

  return { updated, errors };
}
```

### 2. Dynamic Getters (`src/api/auth.ts`)

❌ **Anti-pattern** (static, won't reload):
```typescript
const API_KEY = process.env.NAMI_API_KEY || '';

export function validateAuth(req: Request): boolean {
  return safeCompare(extractToken(req), API_KEY);
}
```

✅ **Correct** (dynamic, hot-reload compatible):
```typescript
function getApiKey(): string {
  return process.env.NAMI_API_KEY || '';
}

export function validateAuth(req: Request): boolean {
  return safeCompare(extractToken(req), getApiKey());
}
```

### 3. API Endpoint

```typescript
import { reloadEnv } from '../config/env.js';

const postReloadEnv: Handler = async () => {
  const result = reloadEnv();
  const msg = result.updated.length > 0
    ? `Reloaded ${result.updated.length} vars: ${result.updated.join(', ')}`
    : 'No changes detected';
  return json({ success: result.errors.length === 0, message: msg, ...result });
};

// In routes array:
route('POST', '/api/reload-env', postReloadEnv)
```

## Usage

After editing `.env` on server:

```bash
curl -X POST http://server:3000/api/reload-env \
  -H "Authorization: Bearer YOUR_API_KEY"
```

Response:
```json
{
  "success": true,
  "message": "Reloaded 2 vars: POSTHOG_API_KEY, MODEL_NAME",
  "updated": ["POSTHOG_API_KEY", "MODEL_NAME"],
  "errors": []
}
```

## Caveats

1. **Config objects cached** — If you cache `loadConfig()` result at startup, it won't benefit. Re-read `process.env` on each access or invalidate cache after reload.
2. **Module-level constants** — Any `const X = process.env.Y` at top-level won't update. Use getters.
3. **File watch alternative** — Could use `fs.watch()` on `.env` for auto-reload, but API endpoint gives more control.

## Related

- File: `src/config/env.ts` (NamiOS server)
- File: `src/api/auth.ts` (dynamic API key)
- File: `src/api/routes.ts` (reload endpoint)
