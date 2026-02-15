---
type: map
project: namios
date: 2026-02-14
---

# NamiOS Documentation Map

Quick reference to all project knowledge. Start here when beginning a new session.

## Architecture

| Component | Path | Purpose |
|-----------|------|---------|
| **NamiEntity** | `Sources/Features/Nami/NamiEntityView.swift` | Wave-shaped fluid entity with face, touch, audio reactivity |
| **ChatView** | `Sources/Features/Chat/ChatView.swift` | Main chat interface with message history |
| **ChatHeaderNami** | `Sources/Features/Chat/ChatHeaderNami.swift` | Isolated header with Nami entity (prevents re-render cascade) |
| **PushNotificationManager** | `Sources/Core/Network/PushNotificationManager.swift` | APNs registration and token handling |
| **WebSocketManager** | `Sources/Core/Network/WebSocketManager.swift` | Real-time chat via ws:// |
| **TextToSpeechService** | `Sources/Core/TTS/TextToSpeechService.swift` | ElevenLabs TTS integration |
| **SpeechRecognizer** | `Sources/Core/Speech/SpeechRecognizer.swift` | Apple Speech Recognition |
| **MeowApp** (legacy name) | `Sources/MeowApp.swift` | App entry point with platform-specific delegates |
| **Mac Agent** | `/Users/alekdob/nami-agent/server.js` | Local Node.js daemon for remote Mac access |
| **Mac Remote Tools** | `src/tools/mac-remote.ts` | Nami tools: macFileRead + macExec |

## Known Issues & Fixes

### Critical
- **WebSocket stream stuck** (Feb 6) — See `bugs/websocket-stream-stuck-after-tool-use.md`
- **WebSocket stale isConnected** (Feb 13) — See `bugs/fix-websocket-stale-connected-send-failure.md`
- **WebSocket lost response recovery** (Feb 13) — See `bugs/fix-websocket-lost-response-recovery.md`
- **WebSocket reconnect infinite loop** (Feb 15) — See `bugs/fix-websocket-reconnect-infinite-loop.md`
- **macOS ViewBridge crash** (Feb 9) — See `bugs/fix-macos-viewbridge-crash-missing-appdelegate.md`
- **macOS APNs not registering** (Feb 9) — See `bugs/fix-macos-apns-registration-appkit.md`
- **99% CPU on macOS** (Feb 9) — See `bugs/fix-macos-99-percent-cpu-observable-cascade.md`
- **@Observable cascade + scroll freeze** (Feb 15) — See `bugs/fix-observable-cascade-macos-scroll-freeze.md`
- **WS recovery chain + push tap empty** (Feb 15) — See `bugs/fix-websocket-recovery-chain-and-push-tap.md`
- **NSSpeechRecognition crash** (Feb 2) — See `bugs/fix-nsspeechrecognition-usage-description-crash.md`

### Platform
- **WKWebView macOS sandbox** (Feb 5) — See `bugs/fix-wkwebview-macos-sandbox-loadhtmlstring.md`
- **Preview endpoint 401** (Feb 5) — See `bugs/fix-preview-endpoint-auth-bypass.md`

### Backend
- **MCP Loader stdio transport** (Feb 12) — See `bugs/fix-mcp-loader-stdio-transport-missing.md`

## Patterns

| Pattern | File | Use Case |
|---------|------|----------|
| **Mac Remote Access** | `patterns/pattern-mac-remote-access-tailscale-agent.md` | Tailscale + local agent for remote file/command access from server |
| **Push notification race** | `patterns/pattern-ios-push-notification-race-condition.md` | APNs token arrives before manager assigned |
| **MCP server testing** | `patterns/pattern-mcp-server-testing-http-stdio.md` | Test MCP servers before integrating |
| **Session-as-source-of-truth** | `patterns/pattern-session-as-source-of-truth-mobile-websocket.md` | Handle unreliable WebSocket on mobile |
| **Env hot reload** | `patterns/pattern-env-hot-reload-without-restart.md` | Reload env vars without restarting |
| **Voice input (SFSpeech)** | `patterns/pattern-swiftui-voice-input-sfspeechrecognizer.md` | Push-to-talk with waveform visualization |
| **Self-managing skills** | `patterns/pattern-self-managing-skills.md` | Agent creates its own .md skill files at runtime |
| **Light mode code blocks** | `patterns/pattern-swiftui-light-mode-code-blocks.md` | Dark background code blocks in both themes |
| **NPM versioning** | `patterns/pattern-npm-versioning-workflow.md` | npm publish + GitHub sync workflow |
| **WebSocket broadcast** | `patterns/pattern-websocket-broadcast-creations.md` | Real-time creation notifications to clients |

## Decisions

| Decision | File | Status |
|----------|------|--------|
| **Tailscale over SSH tunnel** | `decisions/decision-tailscale-over-ssh-tunnel.md` | Accepted |
| **Raycast quick input macOS** | `decisions/decision-raycast-quick-input-macos.md` | Implemented |
| **SFSpeechRecognizer before WhisperKit** | `decisions/decision-sfspeechrecognizer-before-whisperkit.md` | Active |
| **Open Source + Services model** | `decisions/decision-open-source-services-model.md` | Approved |
| **Repo separation public/private** | `decisions/decision-repo-separation-public-private.md` | Implemented |

## Gotchas

| Gotcha | File |
|--------|------|
| **URLSession WebSocket stale isConnected** | `gotchas/gotcha-urlsession-websocket-stale-isconnected.md` |
| **@Observable cascade re-renders** | `gotchas/gotcha-observable-cascade-rerender.md` |
| **Mixpanel token CLI arg** | `gotchas/gotcha-mcp-mixpanel-token-cli-arg.md` |
| **MCP configuration patterns** | `gotchas/gotcha-mcp-configuration-patterns-http-vs-stdio.md` |
| **Animation on LazyVStack** | `gotchas/gotcha-animation-on-lazyvstack.md` |

## Guides

| Guide | File | Audience |
|-------|------|----------|
| **Server Architecture** | `guide/server/architecture.md` | Developers |
| **Server Setup** | `guide/server/setup.md` | Developers |
| **Server Usage** | `guide/server/usage.md` | Developers |
| **API Reference** | `guide/server/api.md` | Developers |
| **Test Plan** | `guide/testing/test-plan.md` | QA/Dev |
| **Push Notifications Test** | `guide/testing/push-notifications.md` | QA/Dev |
| **Project Plan** | `guide/project/plan.md` | All |
| **Agents Context** | `guide/project/agents.md` | AI Agents |

## Platforms
- iOS 17+ / iPadOS 17+ / macOS 14+

## Last Updated
2026-02-15 (Brain migration: 13 entries moved from global Brain to project docs)
