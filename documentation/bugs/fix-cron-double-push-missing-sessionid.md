---
type: bug-fix
project: namios
date: 2026-02-16
severity: medium
tags: [cron, push-notification, APNs, sessionId, deep-link, systemd]
related: [fix-websocket-recovery-chain-and-push-tap.md, gotcha-duplicate-systemd-services.md]
---

# Cron Job Double Push Notification + Missing SessionId

## Symptom
1. **Two push notifications per cron job**: "Task firing" (when job starts) + "Task: ..." (when AI responds)
2. **Tap on notification opens nothing**: app opens but doesn't navigate to the conversation
3. **Jobs potentially firing twice**: two systemd services running the same codebase

## Root Cause

### Double Push
The scheduler had two notification points, both sending APNs push:

```typescript
// onNotify — fires when job starts
scheduler.onNotify = (job) => {
  sendPushNotification('Task firing', job.name + ': ' + job.task); // Push #1
};

// onTrigger — fires when AI finishes
const scheduler = new Scheduler(dataDir, async (job) => {
  const result = await agent.run(jobMessages);
  await sendPushNotification('Task: ' + job.name, result.slice(0, 200)); // Push #2
});
```

### Missing SessionId
Both push calls omitted `sessionId` — the third parameter. The APNs payload sent `sessionId: null`, so the iOS app's tap handler had no session to navigate to.

The cron `onTrigger` executed `agent.run()` directly (not via WebSocket), so no session was created in the SessionStore. The result existed only in the Discord notification and stdout.

### Duplicate Services
Both `meow.service` and `nami.service` were active, running the identical `bun run src/bin.ts`. Both loaded the same `jobs.json`, so each cron job could fire from both processes.

## Fix

### 1. Remove "Task firing" push (keep Discord + WS broadcast only)
```typescript
scheduler.onNotify = (job) => {
  sendDiscordNotification(alert);
  broadcastNotification(job.name, job.task); // WS clients only
  // No push — only send push when result is ready
};
```

### 2. Create session in cron onTrigger + pass sessionId
```typescript
const sessions = new SessionStore(dataDir);
await sessions.init();

const scheduler = new Scheduler(dataDir, async (job) => {
  const result = await agent.run(jobMessages);
  // Persist to session so push tap can deep-link
  const session = await sessions.createSession('job', job.name);
  await sessions.appendMessage(session.id, 'user', job.task);
  await sessions.appendMessage(session.id, 'assistant', result);
  await sendPushNotification('Task: ' + job.name, result.slice(0, 200), session.id);
});
```

### 3. Disable duplicate service
```bash
systemctl stop meow && systemctl disable meow
```

## Key Insight
Cron jobs that run `agent.run()` directly (outside WebSocket) must create their own sessions if the result needs to be accessible from the mobile app. The session is the bridge between server-side execution and client-side deep linking.

## Files Modified
- `src/cli/index.ts` — SessionStore import, session creation in onTrigger, removed push from onNotify
- `src/sessions/types.ts` — Added `'job'` to `SessionSource` union type

## Verification
- Server: only `nami.service` active (1 process)
- Next cron job should produce 1 push notification with sessionId
- Tapping notification should open the conversation with the AI response
