---
title: "WebSocket Reconnect Infinite Loop (CPU 99%)"
date: 2026-02-15
type: bug
tags: [websocket, reconnect, infinite-loop, cpu, macos, ios]
severity: critical
status: fixed
---

# Bug: WebSocket Reconnect Infinite Loop

## Symptom
App freezes at CPU 99% when pressing Send with server unreachable. macOS becomes completely unresponsive. Memory stays low (67MB) — pure CPU spin, not a memory leak.

## Root Cause

`WebSocketManager.connect()` had two critical flaws:

```swift
// BEFORE (broken)
func connect() {
    // ...
    webSocketTask = session.webSocketTask(with: url)
    webSocketTask?.resume()
    isConnected = true         // BUG 1: optimistic before confirmation
    reconnectAttempts = 0      // BUG 2: resets counter every time
    startListening()
    startPingTimer()
}
```

**Bug 1: Optimistic `isConnected = true`**
Set before the connection was actually established. When server is unreachable, `startListening()` fails immediately, calling `handleDisconnect()` which sets `isConnected = false`, triggering SwiftUI re-renders.

**Bug 2: Counter reset `reconnectAttempts = 0`**
The reconnect loop was supposed to stop after `maxReconnectAttempts` (5), but `connect()` reset the counter to 0 on every call. So the loop never terminated:

```
connect() → isConnected=true, attempts=0
  → receive fails → handleDisconnect() → isConnected=false
  → attemptReconnect() → attempts was 0, now 1 → connect()
  → connect() → isConnected=true, attempts=0   ← RESET!
  → ... infinite loop
```

Each `isConnected` toggle (true→false→true→false) triggered @Observable re-renders across the entire SwiftUI view tree.

## Fix

```swift
// AFTER (fixed)
func connect() {
    // ...
    webSocketTask = session.webSocketTask(with: url)
    webSocketTask?.resume()
    // DON'T set isConnected = true — wait for confirmed receive
    // DON'T reset reconnectAttempts — only on confirmed connection
    startListening()
}

private func startListening() {
    webSocketTask?.receive { result in
        switch result {
        case .success(let message):
            if !self.isConnected {
                self.isConnected = true        // Confirmed!
                self.reconnectAttempts = 0     // Reset only here
                self.startPingTimer()
            }
            self.handleReceivedMessage(message)
            self.startListening()
        case .failure(let error):
            self.handleDisconnect(error)
        }
    }
}
```

Also added `hasActiveTask` computed property for ChatViewModel to check if a WS task exists (even if not yet confirmed):

```swift
var hasActiveTask: Bool { webSocketTask != nil }
```

## Files Changed
- `Sources/Core/Network/WebSocketManager.swift`
- `Sources/Features/Chat/ChatViewModel.swift` (send path uses `hasActiveTask`)

## Trigger
Press Send when server is unreachable (wrong IP, server down, no network).

## Lesson
Never set connection state optimistically in WebSocket managers. Confirm connection through actual message exchange. Never reset retry counters in the connect function — only when connection is verified.
