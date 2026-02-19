---
type: bug-fix
project: namios
date: 2026-02-13
severity: high
tags: [websocket, iOS, scenePhase, recovery, session-sync]
related: [websocket-stream-stuck-after-tool-use.md]
---

# WebSocket Lost Response Recovery

## Symptom
When user switches away from the app during a chat response (e.g., opens Safari, then returns), the response is lost forever. The UI shows "Connection lost while waiting for response" but the response never appears, even though:
1. The server completed the response and saved it to the session
2. A push notification arrived (indicating completion)
3. The user returned to the app

## Root Cause
The previous fix (Feb 6) handled disconnect detection and UI cleanup, but did NOT implement response recovery. The flow was:

1. User sends message via WebSocket
2. User switches apps → iOS suspends `URLSessionWebSocketTask`
3. Server completes `agent.run()` and persists to `sessions/{id}.json`
4. Server sends `done` message → lost (WebSocket already closed)
5. User returns to app → sees error message, but response is never fetched

**Missing piece**: No mechanism to fetch the lost response from the server after reconnection.

## Fix (3-Part Solution)

### 1. MeowApp.swift — scenePhase Monitoring
Added `@Environment(\.scenePhase)` to detect when app returns to foreground:

```swift
@Environment(\.scenePhase) private var scenePhase

.onChange(of: scenePhase) { _, newPhase in
    if newPhase == .active {
        handleBecameActive()
    }
}

private func handleBecameActive() {
    print("[App] scenePhase → active")
    if !wsManager.isConnected {
        print("[App] WS not connected — reconnecting")
        wsManager.connect()
    }
}
```

**Why**: iOS does NOT automatically reconnect WebSockets when returning from background. Must explicitly call `connect()`.

### 2. WebSocketManager.swift — Reconnection Callback
Added `onReconnect` callback and `hasConnectedBefore` flag:

```swift
var onReconnect: (() -> Void)?
private var hasConnectedBefore = false

func connect() {
    // ... connection logic ...

    if hasConnectedBefore {
        print("[WS] reconnected — notifying listeners")
        onReconnect?()
    }
    hasConnectedBefore = true
}
```

**Why**: Distinguish initial connection from reconnections. Only trigger recovery on reconnect (not first connect).

### 3. ChatViewModel.swift — Response Recovery Logic
Added `setupReconnectHandler()` and retry mechanism:

```swift
private func setupReconnectHandler() {
    wsManager.onReconnect = { [weak self] in
        guard let self else { return }
        self.recoverLostResponse()
    }
}

private func recoverLostResponse() {
    guard let sessionId = currentSessionId else { return }
    guard errorMessage != nil else { return }  // Only recover if there was an error

    Task { @MainActor in
        try? await Task.sleep(for: .seconds(1))  // Server may still be processing
        await fetchMissingMessages(sessionId: sessionId, attempt: 1)
    }
}

private func fetchMissingMessages(sessionId: String, attempt: Int) async {
    let maxAttempts = 3
    let response = try await apiClient.fetchSession(id: sessionId)
    let serverMessages = response.session.messages
    let localCount = messages.filter { $0.role == .user || $0.role == .assistant }.count
    let serverCount = serverMessages.count

    if serverCount > localCount, let lastServer = serverMessages.last, lastServer.role == "assistant" {
        // Found missing response — add it to chat
        let recovered = ChatMessage(role: .assistant, content: lastServer.content)
        messages.append(recovered)
        persistMessage(recovered)
        errorMessage = nil

        if tts.autoSpeak {
            tts.speak(lastServer.content, messageID: recovered.id)
        }
    } else if attempt < maxAttempts {
        // Retry after delay (server may still be writing to session file)
        try? await Task.sleep(for: .seconds(3))
        await fetchMissingMessages(sessionId: sessionId, attempt: attempt + 1)
    }
}
```

**Why**:
- **1-second initial delay**: If user returns quickly, server may still be processing `agent.run()`
- **3 retry attempts with 3-sec intervals**: Handle race condition where session file is being written
- **Only recover if errorMessage is set**: Avoid unnecessary fetches on normal reconnects

## Flow After Fix

1. User sends message via WebSocket
2. User switches apps → iOS suspends `URLSessionWebSocketTask`
3. Server completes `agent.run()`, persists to session, sends `done` (lost)
4. `handleDisconnect()` → sets `errorMessage = "Connection lost while waiting for response"`
5. User returns to app → `scenePhase` → `.active`
6. `handleBecameActive()` → `wsManager.connect()`
7. WebSocket reconnects → `onReconnect` → `recoverLostResponse()`
8. Fetch session via REST (`GET /api/sessions/{id}`)
9. Compare local message count vs server count
10. If server has more messages → append missing response to chat
11. Clear error message, play TTS if enabled

## Key Insights

### URLSessionWebSocketTask Lifecycle on iOS
- **Does NOT auto-reconnect** after app returns from background
- **Does NOT buffer messages** during suspension
- **Silently fails** without errors when suspended mid-response
- **Must explicitly track** "awaiting response" state and handle reconnection manually

### Session-as-Source-of-Truth Pattern
When WebSocket is unreliable (mobile, background suspension), always persist responses server-side and treat session storage as source of truth. Client can then "catch up" after reconnection by diffing local vs server state.

### Retry Strategy
When fetching after reconnection, always implement retry with delay:
- Initial delay: Handle "server still processing" case
- Exponential backoff: Handle "session file being written" race condition
- Max attempts: Prevent infinite retry loops

## Files Modified
- `Sources/MeowApp.swift` — Added scenePhase monitoring and reconnection trigger
- `Sources/Core/Network/WebSocketManager.swift` — Added onReconnect callback and hasConnectedBefore flag
- `Sources/Features/Chat/ChatViewModel.swift` — Added recovery logic with retry mechanism

## Related
- Previous fix: `bugs/websocket-stream-stuck-after-tool-use.md` (Feb 6) — Handled disconnect detection but not recovery
- Server implementation: `src/api/websocket.ts` — Persists responses to `sessions/{id}.json` immediately after completion
