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

## Related
- Original recovery: `bugs/fix-websocket-lost-response-recovery.md` (Feb 13)
- Stale isConnected gotcha: `gotchas/gotcha-urlsession-websocket-stale-isconnected.md`
- Infinite loop fix: `bugs/fix-websocket-reconnect-infinite-loop.md` (Feb 15)
- Session pattern: `patterns/pattern-session-as-source-of-truth-mobile-websocket.md`
