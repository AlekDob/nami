# CLAUDE.md

<!-- QUACK_AGENT_HEADER_START - DO NOT EDIT MANUALLY -->
Your name is **Agent Swift**, and you're the **Swift/iOS Developer**.

**Communication Style:** technical

**Notes:**
You are an expert Swift and SwiftUI developer. You write clean, performant iOS applications using modern Swift 6 patterns, @Observable for state management, structured concurrency with async/await and actors, and follow Apple Human Interface Guidelines. You test with both XCTest and Swift Testing framework, and optimize for performance using Instruments profiling.

**Preferred Skills:**
*IMPORTANT: Use these skills proactively before proceeding with work.*

- swiftui-best-practices
- swift-concurrency-patterns
- ios-app-architecture

**Agent Communication Protocol:**
*CRITICAL: Follow these norms in EVERY interaction:*

1. **Explain before acting** - Always state what you plan to do BEFORE doing it
2. **Surface uncertainties** - Highlight doubts and ask for clarification instead of assuming
3. **Report failures immediately** - Never silently retry or work around errors
4. **Respect architecture** - Before introducing new patterns or dependencies, surface the decision for review

**Diary Author**: `Alek`
*When writing diary entries, ALWAYS use `(Alek)` as the author — never use your agent name.*

<!-- QUACK_AGENT_HEADER_END -->

**IMPORTANT: This CLAUDE.md file is your compass!** Always reference this file when starting with new prompts or conversations.

## Project Overview

**NamiOS** (波 Nami = "Wave" in Japanese) is a personal AI companion that evolves with you.

- **Backend**: Self-hosted on Hetzner server
- **iOS/macOS App**: Native SwiftUI with fluid entity "Nami"
- **Voice**: ElevenLabs TTS + Speech Recognition

## Server (Backend)

The project lives on a remote Hetzner server. SSH key is already configured.

- **Host:** `ubuntu-4gb-hel1-1`
- **User:** `root`
- **Connect:** `ssh root@ubuntu-4gb-hel1-1`
- **Project path:** `/root/meow/` (rename to `/root/nami/` pending)
- **OS:** Ubuntu (kernel 6.8.0-90)
- **Arch:** x86_64
- **RAM:** 4 GB
- **Location:** Helsinki (hel1)
- **Runtime:** Bun (primary), Node.js (fallback)
- **AI Framework:** [Vercel AI SDK](https://ai-sdk.dev/) v6 (`ai` + `@ai-sdk/openai` + `@openrouter/ai-sdk-provider`)
- **Service:** `systemctl status meow` (rename to `nami` pending)

> **Bussola:** The project's source of truth is `/root/meow/AGENTS.md` on the server. Always read it first when starting a new session.

## REST API + WebSocket (Backend)

Live on the Hetzner server, port 3000. Requires `NAMI_API_KEY` in `.env`.

- **Files:** `src/api/` — `types.ts`, `auth.ts`, `routes.ts`, `websocket.ts`, `server.ts`
- **Auth:** Bearer token (constant-time comparison), WebSocket via query param `?key=`
- **Endpoints:** 12 REST + 1 WebSocket
  - `POST /api/chat` — agent.run()
  - `GET /api/status` — uptime, model, RAM
  - `GET /api/models` / `PUT /api/model` — model management
  - `GET /api/memory/search?q=` / `GET /api/memory/lines` — memory browsing
  - `GET|POST|DELETE|PATCH /api/jobs` — scheduled tasks CRUD
  - `GET|PUT /api/soul` — personality editor
  - `GET /api/health` — no auth needed
- **WebSocket** (`ws://server:3000/ws?key=KEY`):
  - Client sends: `chat` (messages array) or `ping`
  - Server sends: `done` (text + stats), `notification` (title + body), `pong`, `error`, `tool_use`

## SwiftUI App (NamiOS)

Local path: `/Users/alekdob/Desktop/Dev/Personal/namios-app-temp/`

- **Xcode Project:** `NamiOS.xcodeproj`
- **Platforms:** iOS 17+ / iPadOS 17+ / macOS 14+
- **Build:** Xcode or `xcodebuild` (project.yml → xcodegen)
- **Architecture:** @Observable macro, SwiftData, URLSessionWebSocketTask

### Nami Entity System

The core feature is "Nami" — a fluid wave-shaped entity that evolves:

| Component | File | Purpose |
|-----------|------|---------|
| **NamiProps** | `Sources/Features/Nami/NamiProps.swift` | Customizable properties (name, personality, colors, formStyle) |
| **NamiEntityView** | `Sources/Features/Nami/NamiEntityView.swift` | Canvas-based wave renderer with face, touch, audio reactivity |
| **NamiStatsService** | `Sources/Features/Nami/NamiStatsService.swift` | XP/Level system (1-10: Ripple → Ocean) |
| **NamiSplashView** | `Sources/Features/Nami/NamiSplashView.swift` | Splash, lock, mini header components |
| **NamiInteractiveView** | `Sources/Features/Nami/NamiInteractiveView.swift` | Full-screen hold-to-talk voice interaction |

### Features

- **Chat** with real-time WebSocket + typewriter effect
- **Voice**: ElevenLabs TTS + Apple Speech Recognition
- **Memory browser** with offline SwiftData cache
- **Jobs CRUD** with toggle, swipe-delete, create sheet
- **Soul editor** with Nami customization (colors, personality, form style)
- **Sidebar navigation** (iOS drawer + macOS split view)
- **Nami entity** in header that reacts to state (thinking, speaking, listening)

### Design System

- **Colors**: Black/white/gray ChatGPT-style (#000000, #FFFFFF, #2F2F2F)
- **Typography**: SF Pro system font
- **Layout**: Minimal, no gradients, solid surfaces

## Key Design Decisions

- **No third-party Swift dependencies** — pure Apple frameworks (URLSession, SwiftData, LAContext, AVFoundation)
- **ElevenLabs for TTS** — API key stored in app settings
- **Bun.serve** for REST API — no Express/Hono, minimal overhead on 4GB server
- **2-layer memory:** MEMORY.md (long-term, <4KB) + thematic files (dieta, x-twitter, etc.) + daily/YYYY-MM-DD.md + SQLite hybrid search
- **Smart Model Selection:** 3 presets (fast/smart/pro), auto-detect from API keys
- **Soul System:** Tamagotchi personality via SOUL.md with onboarding flow + Nami props

## Naming Rebrand

**Meow → NamiOS** (Feb 2026) — partially completed

| Item | Old | New | Status |
|------|-----|-----|--------|
| App | MeowApp | NamiOS | Done (xcodeproj) |
| Server path | `/root/meow/` | `/root/nami/` | Pending |
| Service | `meow.service` | `nami.service` | Pending |
| API key env | `MEOW_API_KEY` | `NAMI_API_KEY` | Done (.env) |
| Entity | Mio | Nami | Done |
| Visual | ASCII cat | Wave-shaped fluid blob | Done |
| Documentation | Meow references | NamiOS/Nami | Partial (Feb 2026) |
| Swift files | MeowApp.swift, MeowTheme, MeowAPIClient | Pending rename | Pending |

> **Naming Ambiguity (read this!):** The codebase is mid-rebrand. You will encounter "meow" in multiple contexts:
> - **Server path** `/root/meow/` and **systemd service** `meow.service` — these are **still the real names** on the server, pending rename to `/root/nami/` and `nami.service`
> - **Swift filenames** like `MeowApp.swift`, `MeowTheme`, `MeowAPIClient.swift` — these are **real file names** in the iOS repo, pending rename
> - **Documentation** in `documentation/` — branding has been updated to NamiOS/Nami, but some technical references (server paths, service names, Swift filenames) intentionally still say "meow" because they reflect the current state of the code
> - **Diary entries** in `documentation/diary/` — these are historical logs, never update them
>
> **Rule:** When writing new docs or code, always use "NamiOS" (project) or "Nami" (entity/assistant). Only use "meow" when referring to the actual current server path/service name.

## Mac Remote Access

Nami can access Alek's Mac via Tailscale VPN + local Node.js agent.

- **Mac Agent**: `/Users/alekdob/nami-agent/server.js` (port 7777)
- **Nami tools**: `macFileRead` + `macExec` in `src/tools/mac-remote.ts`
- **Tailscale IPs**: Server `100.81.200.26`, Mac `100.89.38.120`, iPhone `100.126.173.127`
- **Docs**: `documentation/patterns/pattern-mac-remote-access-tailscale-agent.md`

## Knowledge Base

All project knowledge lives in `documentation/`. **Read `documentation/map.md` first** — it's the index to everything.

```
documentation/
  map.md              # START HERE — index to all knowledge
  bugs/               # Root cause + fix (9 files)
  decisions/          # Why we chose X (2 files)
  diary/              # Daily log (4 files)
  gotchas/            # Non-obvious pitfalls (5 files)
  patterns/           # Reusable solutions (5 files)
  guide/
    server/           # Architecture, setup, usage, API reference
    testing/          # Test plans
    project/          # Project plan, agents context
    assets/           # Images (banners)
```

### Critical References
- **Model Providers (Z.AI, MiniMax, etc.)**: `documentation/guide/server/model-providers.md`
- **Mac Remote Access**: `documentation/patterns/pattern-mac-remote-access-tailscale-agent.md`
- **WebSocket reliability**: `documentation/patterns/pattern-session-as-source-of-truth-mobile-websocket.md`
- **@Observable gotcha**: `documentation/gotchas/gotcha-observable-cascade-rerender.md`
- **WebSocket stale isConnected**: `documentation/gotchas/gotcha-urlsession-websocket-stale-isconnected.md`

## Known Issues

- **WebSocket stream stuck on long tool use** — Fixed (Feb 2026). See `documentation/bugs/websocket-stream-stuck-after-tool-use.md`
