---
type: gotcha
project: namios
created: 2026-02-13
tags: [websocket, ios, background-suspension, swift, urlsession]
---

# Gotcha: URLSessionWebSocketTask isConnected Stale After Background Suspension

## The Trap

On iOS, when your app is suspended in the background, `URLSessionWebSocketTask` **stops responding but doesn't call disconnect handlers**. When the user returns, `isConnected` is still `true`, but the socket is dead.

```swift
// Danger: isConnected == true, but socket is dead
if wsManager.isConnected {
    wsManager.sendMessage("Hello") // Fails silently, no error thrown
}
```

This causes:
- Silent send failures (message lost, no error)
- REST fallback never triggered (no error caught)
- User thinks message was sent but it never reaches the server

## Why This Happens

1. **URLSessionWebSocketTask is OS-managed** — iOS can suspend it without notifying your code
2. **WebSocket runs in a background task** — When your app suspends, the background task is paused
3. **No error handler fires** — The socket doesn't throw an error; it just stops responding
4. **Flag stays stale** — `isConnected` was set to `true` on `resume()` and never reset

## When This Bites You

**Most likely trigger**: User switches apps mid-message and returns via push notification

```
1. User taps send message
2. WS send starts
3. User opens Safari (app goes to background)
4. URLSessionWebSocketTask suspended
5. User taps push notification from NamiOS
6. App returns to foreground
7. `isConnected` is still `true`
8. Next send attempt fails silently
```

## The Fix

**Treat send failures as full disconnections**:

```swift
do {
    try await task.send(.string(message))
} catch {
    // Don't just log the error — treat as disconnect
    await handleDisconnect()
    onSendFailed?()
    throw error
}
```

Then automatically retry via REST:

```swift
func setupSendFailedHandler() {
    wsManager.onSendFailed = { [weak self] in
        guard let self, let pending = self.pendingRetryMessages else { return }
        for message in pending {
            _ = try? await self.sendViaREST(message)
        }
    }
}
```

## Prevention Strategy

- **Never trust `isConnected` after background suspension** — Always assume it's stale
- **Treat send failures as disconnections** — Not just errors, full state reset
- **Never use `isConnected` as a gate for reconnection** — Use `forceReconnect()` on foreground return instead of `if !isConnected { connect() }`
- **Implement fallback mechanism** — REST API as backup when WS fails
- **Retry automatically** — Don't make users resend manually
- **Monitor via logging** — Log all send failures to detect this pattern

## This Gotcha Has Two Attack Surfaces

1. **Send path** (Feb 13): `isConnected == true` but send fails silently. Fix: treat send failure as disconnect + REST retry.
2. **Reconnect path** (Feb 15): `handleBecameActive()` checks `isConnected`, sees `true`, skips reconnect. Recovery chain never fires. Fix: always `forceReconnect()` on foreground return, never gate on `isConnected`.

## Related Documentation

- Bug fix (send path): `bugs/fix-websocket-stale-connected-send-failure.md`
- Bug fix (reconnect path): `bugs/fix-websocket-recovery-chain-and-push-tap.md`
- Response recovery: `bugs/fix-websocket-lost-response-recovery.md`

## Impact

**Severity**: High — Silent message loss, user-facing reliability issue

**Affected**: Any iOS/macOS app using URLSessionWebSocketTask that transitions to background mid-connection

**Workaround**: Always implement REST API fallback + automatic retry for WebSocket sends
