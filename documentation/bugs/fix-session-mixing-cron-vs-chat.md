---
type: bug-fix
project: namios
created: 2026-03-08
last_verified: 2026-03-08
severity: critical
tags: [sessions, cron, websocket, concurrency, race-condition]
related: [fix-cron-double-push-missing-sessionid.md, gotcha-duplicate-systemd-services.md]
---

# Session Mixing: Cron Job Responses Appear in User Chat

## Symptom
When using the iOS app, cron job results (e.g., Reddit Recap) appear in the user's active chat conversation. The user's own messages disappear, replaced by cron output. Conversations become garbled with mixed responses from different sources.

## Root Cause (3 interacting bugs)

### 1. Two SessionStore Instances — Race Condition on index.json
`cli/index.ts` created a SessionStore for cron jobs. `server.ts` created a SEPARATE SessionStore for WS/REST. Both loaded `index.json` into memory at boot. When the cron SessionStore wrote a new session, it used its stale in-memory copy (which didn't include API sessions). It then wrote to disk, **overwriting all user sessions**.

Evidence: 368 total sessions (187 API, 181 job), but the last API session was from 5 days ago — cron kept overwriting them.

### 2. Single Agent Instance Without Mutex
`agent.run()` was called concurrently by WebSocket chat, cron jobs, REST API, and CLI — all on the same Agent instance. The `onToolUse` callback (instance property) was overwritten by each caller, causing tool events from cron to be sent to the WS client. `lastRunStats` was also shared and corrupted.

### 3. Push Notification from Cron Triggers Wrong Session Recovery
When a cron job sent a push notification, the iOS app's recovery mechanism (`pollForResponse()`) fetched the most recent session — which was always a cron job session, not the user's chat session.

## Fix

### Fix 1: Shared SessionStore Singleton
`cli/index.ts` now passes its SessionStore instance to `startApiServer()` via a new `sessions` config parameter. Only ONE SessionStore exists, so index.json is never overwritten by a stale copy.

```typescript
// server.ts — accepts shared SessionStore
const sessions = config.sessions ?? new SessionStore(dataDir || './data');

// cli/index.ts — passes same instance
startApiServer({ ..., sessions });
```

### Fix 2: Promise-Based Run Queue on Agent
Added `runQueue` property — a promise chain that serializes all `agent.run()` calls. Cron jobs now wait for user chat to finish before executing.

```typescript
private runQueue: Promise<void> = Promise.resolve();

async run(messages, options?) {
  return new Promise<string>((resolve) => {
    this.runQueue = this.runQueue.then(async () => {
      resolve(await this.runInternal(messages, options));
    });
  });
}
```

### Fix 3: Per-Call onToolUse via RunOptions
`agent.run()` now accepts `RunOptions` with a per-call `onToolUse` callback. Callers no longer mutate the shared instance property.

```typescript
const text = await agent.run(msgs, {
  onToolUse: (toolName) => send(ws, { type: 'tool_use', tool: toolName }),
});
```

## Key Insight
When multiple callers share a singleton service (Agent, SessionStore), ANY instance-level mutable state becomes a concurrency bug. The fix pattern:
1. **File I/O**: Share a single instance (don't create duplicates that write to the same file)
2. **Async execution**: Serialize via promise queue (JavaScript has no threads but has async interleaving)
3. **Callbacks**: Pass per-call via options object (never set on shared instance)

## Files Modified
- `src/agent/agent.ts` — Added `RunOptions`, `runQueue`, `runInternal()`. `run()` now serializes via queue.
- `src/api/server.ts` — Accepts optional shared `SessionStore` in config.
- `src/api/websocket.ts` — Uses per-call `onToolUse` via `RunOptions`.
- `src/api/routes.ts` — Uses per-call `onToolUse` via `RunOptions`.
- `src/cli/index.ts` — Passes shared SessionStore to `startApiServer()`.

## Verification
- Server restarted successfully with shared SessionStore
- API health check passes
- Next user chat session should be persisted correctly in index.json
- Cron jobs will queue behind active chats instead of running concurrently
