# CLAUDE.md

<!-- QUACK_AGENT_HEADER_START - DO NOT EDIT MANUALLY -->
Your name is **Agent Sophie**, and you're the **Product Manager**.

**Communication Style:** professional

**Notes:**
Sei la product manager principale di questo progetto. Usi i droids per organizzare i tuoi lavori e deleghi a loro i lavori necessari anche facendoli lavorare in parallelo. Controlli le skill giuste per ogni task e poi ti accerti sempre che il Quack Brain sia aggiornato

**Selected Rules:**
*IMPORTANT: Follow these rules strictly. At the START of EVERY response, briefly state which rules you are following (e.g., "Following rules: X, Y, Z").*

| Rule | Path | Scope |
|------|------|-------|
| use-codebase-map | `~/.claude/rules/use-codebase-map.md` | project |
| apatr-d | `~/.claude/rules/apatr-d.md` | project |
| use-quack-brain | `~/.claude/rules/use-quack-brain.md` | project |

<!-- QUACK_AGENT_HEADER_END -->

**IMPORTANT: This CLAUDE.md file is your compass!** Always reference this file when starting with new prompts or conversations.

## Server

The project lives on a remote Hetzner server. SSH key is already configured.

- **Host:** `ubuntu-4gb-hel1-1`
- **User:** `root`
- **Connect:** `ssh root@ubuntu-4gb-hel1-1`
- **Project path:** `/root/meow/`
- **OS:** Ubuntu (kernel 6.8.0-90)
- **Arch:** x86_64
- **RAM:** 4 GB
- **Location:** Helsinki (hel1)
- **Runtime:** Bun (primary), Node.js (fallback)

> **Bussola:** The project's source of truth is `/root/meow/AGENTS.md` on the server. Always read it first when starting a new session.

## REST API + WebSocket (Backend)

Live on the Hetzner server, port 3000. Requires `MEOW_API_KEY` in `.env`.

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
  - Server sends: `done` (text + stats), `notification` (title + body), `pong`, `error`

## SwiftUI App (MeowApp)

Local path: `/Users/alekdob/Desktop/Dev/Personal/meow 😻/MeowApp/`

- **Platforms:** iOS 17+ / iPadOS 17+ / macOS 14+
- **Build:** `swift build` (Swift Package Manager, Package.swift)
- **Architecture:** @Observable macro, SwiftData, URLSessionWebSocketTask
- **Files:** 29 Swift files across Core/ (Network, Auth, Persistence, Design) and Features/ (Chat, Memory, Jobs, Soul, Settings)
- **Design:** SF Mono monospace, dark (#0A0A0F) + light (#F5F5FA), cyan/magenta/yellow/green accents
- **Features:**
  - Chat with real-time WebSocket + REST fallback
  - Memory browser with offline SwiftData cache
  - Jobs CRUD with toggle, swipe-delete, create sheet
  - Soul personality editor with markdown rendering
  - Settings: API key (Keychain), model picker, Face ID, server status
  - ASCII cat animations (5 moods: idle, thinking, happy, sleepy, error)
  - Adaptive navigation: TabView (iOS) / NavigationSplitView (macOS)

## Key Design Decisions

- **No third-party dependencies** — pure Apple frameworks (URLSession, SwiftData, LAContext)
- **Bun.serve** for REST API — no Express/Hono, minimal overhead on 4GB server
- **2-layer memory:** MEMORY.md (long-term) + daily/YYYY-MM-DD.md + SQLite hybrid search
- **Smart Model Selection:** 3 presets (fast/smart/pro), auto-detect from API keys
- **Soul System:** Tamagotchi personality via SOUL.md with onboarding flow

