---
type: bug-fix
project: namios
date: 2026-02-15
severity: high
tags: [websocket, iOS, recovery, push-notification, scenePhase, forceReconnect]
related: [fix-websocket-lost-response-recovery.md, gotcha-urlsession-websocket-stale-isconnected.md]
---

# WebSocket Recovery Chain Failure + Push Notification Tap Empty

## Symptom
Two related issues when user sends a message, backgrounds the app, then returns:

1. **"Connection lost while waiting for response"** error appears and never resolves automatically. The response exists on the server but the recovery mechanism never fetches it.
2. **Push notification tap does nothing** — tapping the Nami notification opens the chat but the response is not displayed.

## Root Cause 1: Recovery Chain Broken by Stale `isConnected`

The Feb 13 recovery mechanism (`fix-websocket-lost-response-recovery.md`) implemented a chain:
```
scenePhase → active → handleBecameActive() → wsManager.connect() → onReconnect → recoverLostResponse()
```

But `handleBecameActive()` checked `isConnected` before deciding to reconnect:
```swift
// BEFORE (broken)
private func handleBecameActive() {
    if !wsManager.isConnected {
        wsManager.connect()  // Never called if isConnected is stale!
    }
}
```

iOS kills the WebSocket silently in background without delivering disconnect errors. So `isConnected` stays `true`, `connect()` is never called, `onReconnect` never fires, and recovery never happens.

This is the same stale `isConnected` gotcha documented in `gotcha-urlsession-websocket-stale-isconnected.md`, but in a different context: the gotcha covers send failures, this covers reconnection decision.

## Root Cause 2: Empty Push Notification Tap Handler

`PushNotificationManager.didReceive` only logged the tap:
```swift
// BEFORE (broken)
func userNotificationCenter(...didReceive...) {
    print("[Push] Notification tapped: \(title)")
    completionHandler()  // No navigation, no session loading
}
```

Additionally, the server's APNs payload did not include `sessionId`, so even with a proper handler there was no way to know which session to load.

## Fix (4-Part Solution)

### 1. WebSocketManager — `forceReconnect()` method
New method that tears down the connection unconditionally, bypassing stale `isConnected`:

```swift
func forceReconnect() {
    isConnected = false
    reconnectAttempts = 0
    disconnect()
    connect()
}
```

### 2. MeowApp — Always force reconnect on foreground
```swift
// AFTER (fixed)
private func handleBecameActive() {
    wsManager.forceReconnect()  // Never trust isConnected after background
    NotificationCenter.default.post(name: .appBecameActive, object: nil)
}
```

### 3. Dual-Path Recovery in ChatViewModel
- **Path A (WS)**: `onReconnect` callback fires after WS reconnects, triggers `recoverLostResponse()`
- **Path B (REST fallback)**: `appBecameActive` observer with 3-second delay. If `onReconnect` didn't clear the error within 3s, triggers `recoverLostResponse()` directly via REST.

### 4. Push Notification Tap Handler + Server SessionId
**Server**: `sendPushNotification(title, body, sessionId)` now includes `sessionId` in APNs `userInfo`.

**Client**: `didReceive` extracts `sessionId` from `userInfo`, posts `navigateToChat` with it. `ContentView` observer calls `chatVM.loadSessionById(sessionId)`.

## Key Insight

The stale `isConnected` gotcha affects more than just send operations — it also breaks reconnection logic. Any code path that uses `isConnected` as a gate for reconnection will fail after iOS background suspension. The safe pattern is: **always force reconnect on foreground return**.

## Files Modified
- `Sources/Core/Network/WebSocketManager.swift` — Added `forceReconnect()`
- `Sources/MeowApp.swift` — `handleBecameActive()` uses `forceReconnect()` + posts notification
- `Sources/Features/Chat/ChatViewModel.swift` — Added `appBecameActive` fallback observer
- `Sources/Core/Network/PushNotificationManager.swift` — Real tap handler with sessionId
- `Sources/ContentView.swift` — `navigateToChat` observer loads session by ID
- `src/channels/apns.ts` (server) — Added `sessionId` param to push payload
- `src/api/websocket.ts` (server) — Passes `sessionId` to `sendPushNotification()`

## Iterative Fixes (Same Session)

The initial 4-part fix revealed several follow-up bugs during live testing:

### Fix 5: `scenePhase → active` fires on first launch too
`forceReconnect()` killed the initial WS connection at startup because `scenePhase → active` fires both on first launch AND return from background. Fix: added `hasBeenBackgrounded` flag in MeowApp — `handleBecameActive()` guards on `didConfigure && hasBeenBackgrounded`.

### Fix 6: Recovery guard condition tied to `errorMessage` breaks when error is hidden
After removing the "Connection lost" error message from UI (`errorMessage` no longer set by disconnect/handleError), all recovery paths stopped working because they used `guard errorMessage != nil`. Fix: changed all 4 guard conditions to use `isThinking` instead — the true indicator that a response is pending.

### Fix 7: `currentSessionId` is nil for first conversation
When user sends the first message, `currentSessionId` is nil until the WS `done` response assigns it. If WS dies before receiving the response, recovery can't fetch the session. Fix: `pollForResponse()` falls back to `fetchSessions()` and takes the most recent session from the server.

### Fix 8: `loadSession()` doesn't reset `isThinking`
Tapping a push notification calls `loadSessionById → loadSession`, which loads the response but never sets `isThinking = false`. Result: response text visible but wave animation continues, send button disabled. Fix: added `isThinking = false` and `activeTools = []` to `loadSession()`.

### Fix 9: `willPresent` only fires in foreground
Push notification `willPresent` delegate is NOT called when app is in background — iOS shows the notification directly. Recovery via push-triggered `pushResponseArrived` notification only works when app is already in foreground. The primary recovery path must be `appBecameActive` (foreground return), not push arrival.

## Final Recovery Architecture

```
pollForResponse() — single method, called by all 3 triggers:
├── If currentSessionId exists → fetchSession(id) directly
├── If nil → fetchSessions(), take .first (sorted by updatedAt desc)
├── Compare serverCount > localCount → append recovered message
├── Set isThinking = false, start typewriter, auto-speak
├── 12 retries × 5s = ~60s max polling
└── On all retries exhausted → isThinking = false (stop spinner)

Triggers (all call recoverLostResponse → pollForResponse):
1. appBecameActive notification (immediate, most reliable)
2. WS onReconnect callback (fires after successful reconnect)
3. pushResponseArrived notification (foreground push only)
```

## Related
- Original recovery: `bugs/fix-websocket-lost-response-recovery.md` (Feb 13)
- Stale isConnected gotcha: `gotchas/gotcha-urlsession-websocket-stale-isconnected.md`
- Infinite loop fix: `bugs/fix-websocket-reconnect-infinite-loop.md` (Feb 15)
- Session pattern: `patterns/pattern-session-as-source-of-truth-mobile-websocket.md`
