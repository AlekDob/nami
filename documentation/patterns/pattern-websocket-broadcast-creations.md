---
date: 2026-02-05
type: pattern
tags: [websocket, realtime, swiftui, bun]
---

# Pattern: WebSocket Broadcast for Real-time Notifications

When Nami creates something (app, document), all connected clients get notified in real-time via WebSocket broadcast.

## Backend (Bun WebSocket)

```typescript
const clients = new Set<ServerWebSocket<{ key: string }>>();

export function broadcastCreation(creation: {
  id: string; type: string; name: string; path: string;
}) {
  const message = JSON.stringify({ type: 'creation', creation });
  for (const client of clients) { client.send(message); }
}
```

## SwiftUI Client

```swift
// In WebSocketManager, handle incoming message:
case "creation":
    if let data = try? JSONDecoder().decode(
        WSIncoming.CreationPayload.self, from: json["creation"]
    ) {
        onCreation?(data)
    }
```

## Flow

```
1. Nami usa fileWrite per creare apps/todo-list/index.html
2. fileWrite chiama registerCreation()
3. registerCreation() salva + broadcastCreation()
4. WebSocket invia { type: "creation", creation: {...} }
5. SwiftUI riceve, aggiunge CreationBanner alla chat
6. Utente tappa banner → naviga a sezione OS
```

## Key Points

- Mantenere `Set<WebSocket>` per broadcast efficiente
- Usare enum con associated values per type-safe message parsing
- Banner deve essere cliccabile, non solo informativo

## Related

- `patterns/pattern-session-as-source-of-truth-mobile-websocket.md` — Session recovery pattern
- `bugs/fix-websocket-reconnect-infinite-loop.md` — Reconnect safety
