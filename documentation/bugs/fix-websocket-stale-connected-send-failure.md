---
type: bug_fix
project: namios
created: 2026-02-13
tags: [websocket, ios, network, background-suspension, swift]
---

# Fix: WebSocket Stale isConnected Causes Silent Message Loss

## Problem

After returning to the app via push notification tap, sending a second message fails silently with "Could not connect to the server." The first message after reconnection works fine, but subsequent messages fail without triggering any retry logic.

## Root Cause

iOS suspends `URLSessionWebSocketTask` when the app enters background. When the user returns to the app:

1. `URLSessionWebSocketTask` is suspended but not disconnected
2. `isConnected` flag remains `true` (stale state)
3. `handleDisconnect()` was never called because iOS suspended the socket without raising an error
4. `sendMessage()` sees `isConnected == true` and attempts to send via the dead socket
5. `task.send()` fails silently (no error thrown, just fails to send)
6. REST fallback is never triggered because no error was caught
7. Message is lost forever

## Solution

**WebSocketManager.swift** — Treat send failure as full disconnect:
```swift
private func sendMessage(_ message: String) async throws {
    guard isConnected else {
        throw WebSocketError.notConnected
    }

    do {
        try await task.send(.string(message))
    } catch {
        // Send failed on dead socket — treat as disconnect
        await handleDisconnect()
        onSendFailed?()
        throw error
    }
}
```

**Changes**:
- `sendMessage()` now calls `handleDisconnect()` on send failure (not just `handleError`)
- Added `onSendFailed: (() -> Void)?` callback to notify ChatViewModel
- `handleDisconnect` resets `isAwaitingResponse` before disconnecting to avoid double-handler invocation

**ChatViewModel.swift** — Auto-retry failed sends via REST:
```swift
func setupSendFailedHandler() {
    wsManager.onSendFailed = { [weak self] in
        guard let self, let pending = self.pendingRetryMessages else { return }
        Task {
            for message in pending {
                _ = try? await self.sendViaREST(message)
            }
            self.pendingRetryMessages = nil
        }
    }
}
```

**Changes**:
- Added `pendingRetryMessages: [ChatMessage]?` to store messages before WS send attempt
- Added `setupSendFailedHandler()` which listens for `onSendFailed` callback
- On send failure, automatically retries the pending messages via REST API
- Clears `pendingRetryMessages` after `done` or `toolUse` (confirms WS send succeeded)

## New Flow After Fix

```
User sends message
  ↓
Store in pendingRetryMessages
  ↓
Attempt WS send
  ↓
[If WS is dead] Send fails → onSendFailed fires
  ↓
Automatically retry pendingRetryMessages via REST
  ↓
REST sends message → response arrives normally
  ↓
done/toolUse received → clear pendingRetryMessages
  ↓
WS reconnects in background for future messages
```

## Key Insight

`isConnected = true` set immediately on `resume()` means "handshake started", not "connection established". URLSessionWebSocketTask suspends silently without firing error handlers, leaving the flag stale.

**Rule**: Always treat send failures as full disconnections. Never assume `isConnected` reflects reality after iOS background suspension.

## Related Fixes

This is a **companion fix** to `bugs/fix-websocket-lost-response-recovery.md` (same session, Feb 13):
- **Lost Response Fix**: Handles recovery AFTER disconnect is detected (refetch from server)
- **Stale Connected Fix**: Handles the case where socket APPEARS connected but is dead (silent send failure)

Together, they form a 2-part iOS WebSocket resilience system:
1. Detect dead sockets on send failure
2. Retry failed sends via REST
3. Reconnect on app return from background
4. Recover responses already computed server-side

## Files Modified

- `Sources/Core/Network/WebSocketManager.swift` — Send failure handler
- `Sources/Features/Chat/ChatViewModel.swift` — Pending message retry logic

## Verification

**Test case**: Send message → Switch app immediately → Return to app → Send second message

Before fix: Second message lost, no recovery attempt
After fix: Second message sent via REST, appears in chat normally
