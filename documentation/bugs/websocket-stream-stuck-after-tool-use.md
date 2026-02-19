---
type: bug-fix
project: namios
date: 2026-02-06
severity: high
tags: [websocket, streaming, iOS, tool-use, state-management]
---

# WebSocket Stream Stuck After Tool Use

## Symptom
When Nami uses tools (e.g., creating an app), the stream appears stuck indefinitely. Push notification arrives (confirming server completed), but the app UI stays in "thinking" state with spinner. User must force-quit and reopen.

## Root Cause
The WebSocket connection drops silently during long-running agent operations (30-120s tool use), but `ChatViewModel.isThinking` is never reset because:

1. `WebSocketManager` had no mechanism to notify about disconnections during active operations
2. `ChatViewModel` only resets `isThinking` on receiving `done` or `error` messages
3. When connection drops, these messages are lost — push notification arrives via separate APNs channel

## Fix
1. **WebSocketManager.swift**: Added `isAwaitingResponse` flag (set on `sendChat`, cleared on `done`/`error`) and `onDisconnect` callback that fires when connection drops during active response
2. **ChatViewModel.swift**: Added `setupDisconnectHandler()` that resets `isThinking`, clears `activeTools`, and shows error message on disconnect
3. **Server websocket.ts**: Added logging for connect/disconnect/send events to monitor connection lifecycle

## Key Insight
`URLSessionWebSocketTask` in iOS can silently die when the app goes to background or screen locks during long operations. Always track "awaiting response" state and handle disconnection as a terminal event.
