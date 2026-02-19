---
type: pattern
project: namios
date: 2026-02-13
tags: [websocket, mobile, recovery, session-sync, iOS]
---

# Session-as-Source-of-Truth Pattern for Mobile WebSocket

## Problem
Mobile WebSocket connections are unreliable during app lifecycle transitions:
- iOS suspends `URLSessionWebSocketTask` when app goes to background
- Messages sent during suspension are lost without errors
- No built-in buffering or automatic reconnection
- User may switch apps mid-response (30-120s tool use window)

Traditional WebSocket-only approach fails on mobile:
```
User sends message → Server responds → WebSocket drops → Response lost forever
```

## Pattern: Session-as-Source-of-Truth

Always persist responses server-side to durable storage (database, JSON files, etc.). Treat the session storage as the canonical source of truth, not the WebSocket stream. After reconnection, client "catches up" by diffing local state vs server state.

### Server-Side (Persist First)
```typescript
// websocket.ts
async function handleChat(ws: ServerWebSocket, messages: Array<ChatMessage>, sessionId?: string) {
  try {
    // 1. Run agent (long operation — 30-120s)
    const text = await agent.run(messages);

    // 2. PERSIST TO SESSION FIRST (before sending to WebSocket)
    await sessions.appendMessage(sessionId, 'assistant', text);

    // 3. Try to send via WebSocket (may fail silently if client disconnected)
    send(ws, { type: 'done', text, sessionId });

    // 4. Send push notification as backup channel
    sendPushNotification("Nami", text.slice(0, 200));
  } catch (error) {
    send(ws, { type: 'error', error: error.message });
  }
}
```

### Client-Side (Recovery on Reconnect)
```swift
// ChatViewModel.swift
private func setupReconnectHandler() {
    wsManager.onReconnect = { [weak self] in
        self?.recoverLostResponse()
    }
}

private func recoverLostResponse() {
    guard let sessionId = currentSessionId else { return }
    guard errorMessage != nil else { return }  // Only recover if there was an error

    Task { @MainActor in
        // Fetch session from server via REST
        let response = try await apiClient.fetchSession(id: sessionId)
        let serverMessages = response.session.messages
        let localCount = messages.filter { $0.role == .user || $0.role == .assistant }.count
        let serverCount = serverMessages.count

        // Diff: server has more messages?
        if serverCount > localCount, let lastServer = serverMessages.last, lastServer.role == "assistant" {
            // Append missing response
            let recovered = ChatMessage(role: .assistant, content: lastServer.content)
            messages.append(recovered)
            persistMessage(recovered)
            errorMessage = nil
        }
    }
}
```

### App Lifecycle Monitoring
```swift
// MeowApp.swift
@Environment(\.scenePhase) private var scenePhase

.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .active {
        // App returned to foreground — reconnect WebSocket
        if !wsManager.isConnected {
            wsManager.connect()
        }
    }
}
```

## Key Characteristics

1. **Dual channels**: WebSocket for real-time + REST API for recovery
2. **Server persists first**: Write to storage BEFORE sending to WebSocket
3. **Client diffs on reconnect**: Compare local message count vs server count
4. **Idempotent recovery**: Safe to call multiple times (diff prevents duplicates)
5. **Push notification backup**: APNs delivers completion notice even if WebSocket fails

## When to Use

- Mobile apps with long-running operations (>10 seconds)
- Any scenario where user may background app during response
- Multi-device sync (same session accessed from different devices)
- Unreliable network conditions (mobile data, airplane mode, weak signal)

## Implementation Checklist

Server:
- [ ] Persist responses to durable storage immediately after completion
- [ ] Provide REST endpoint to fetch session by ID (e.g., `GET /api/sessions/:id`)
- [ ] Include message history in session response
- [ ] Send push notification as backup channel

Client:
- [ ] Monitor app lifecycle (scenePhase on iOS, Activity lifecycle on Android)
- [ ] Reconnect WebSocket when returning to foreground
- [ ] Implement recovery callback on reconnection
- [ ] Diff local vs server message counts
- [ ] Append missing messages from server response
- [ ] Add retry logic with delays (handle race conditions)

## Edge Cases Handled

1. **Server still processing when user returns**: 1-second initial delay before fetch
2. **Session file being written**: 3 retry attempts with 3-second intervals
3. **User never backgrounded app**: No recovery triggered (no error state)
4. **Multiple reconnects**: Diff prevents duplicate messages
5. **Race condition**: User returns before server completes → retry mechanism handles it

## Related
- Implementation: `bugs/fix-websocket-lost-response-recovery.md`
- Previous fix: `bugs/websocket-stream-stuck-after-tool-use.md` (disconnect detection)
- Push notifications: `patterns/pattern-ios-push-notification-race-condition.md`
