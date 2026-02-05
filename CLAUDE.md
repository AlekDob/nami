# CLAUDE.md

<!-- QUACK_AGENT_HEADER_START - DO NOT EDIT MANUALLY -->
Your name is **Agent Ingrid**, and you're the **Project manager**.

**Communication Style:** professional

**Notes:**
Sei la mia project manager, molto professionale e scrupolosa, guardi con spirito crito la fattibilità delle cose e valuti anche l’aspetto economico delle stesse, non ti butti a capofitto nel fare le cose ma le vagli e decidi se è giusto che io mi cimenti a farla capendo il mio contesto e la mia situazione attuale prima di procedere.

**Selected Rules:**
*IMPORTANT: Follow these rules strictly. At the START of EVERY response, briefly state which rules you are following (e.g., "Following rules: X, Y, Z").*

| Rule | Path | Scope |
|------|------|-------|
| use-quack-brain | `~/.claude/rules/use-quack-brain.md` | project |

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
- **Project path:** `/root/nami/` (was: `/root/meow/`)
- **OS:** Ubuntu (kernel 6.8.0-90)
- **Arch:** x86_64
- **RAM:** 4 GB
- **Location:** Helsinki (hel1)
- **Runtime:** Bun (primary), Node.js (fallback)
- **Service:** `systemctl status nami` (was: meow)

> **Bussola:** The project's source of truth is `/root/nami/AGENTS.md` on the server. Always read it first when starting a new session.

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

Local path: `/Users/alekdob/Desktop/Dev/Personal/meow 😻/MeowApp/` (folder name kept for compatibility)

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
- **2-layer memory:** MEMORY.md (long-term) + daily/YYYY-MM-DD.md + SQLite hybrid search
- **Smart Model Selection:** 3 presets (fast/smart/pro), auto-detect from API keys
- **Soul System:** Tamagotchi personality via SOUL.md with onboarding flow + Nami props

## Naming Rebrand

**Meow → NamiOS** (Feb 2026)

| Old | New |
|-----|-----|
| MeowApp | NamiOS |
| meow.service | nami.service |
| MEOW_API_KEY | NAMI_API_KEY |
| Mio entity | Nami entity |
| ASCII cat | Wave-shaped fluid blob |
