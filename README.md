<p align="center">
  <img src="docs/nami-banner.png" alt="NamiOS - Self-Evolving AI Companion" width="600">
</p>

<h1 align="center">NamiOS</h1>

<p align="center">
  <strong>波 Nami — A self-evolving AI companion that grows with you.</strong><br>
  Memory, personality, creations, voice — all yours.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/runtime-Bun%20%7C%20Node.js-blue" alt="Runtime">
  <img src="https://img.shields.io/badge/AI%20SDK-v6-purple" alt="AI SDK">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
  <img src="https://img.shields.io/badge/TypeScript-strict-blue" alt="TypeScript">
  <img src="https://img.shields.io/badge/SwiftUI-iOS%20%7C%20macOS-orange" alt="SwiftUI">
</p>

---

## What is NamiOS?

NamiOS is a **personal AI operating system** — a self-hosted AI companion that evolves over time. It features a fluid wave-shaped entity called **Nami** (波 = "wave" in Japanese), persistent memory, autonomous creations, voice interaction, and scheduled tasks.

No cloud subscriptions. Your data stays on your server.

```
    ～～～
   ～ 👁👁 ～    "create a weather dashboard for me"
    ～～～～～    Nami: On it! Building Weather Hub...
```

## Features

- **Evolving Entity** — Nami is a fluid wave that reacts to voice, touch, and conversation
- **Creation System** — Nami can build mini web apps autonomously (Weather, Cinema, Tools)
- **Agentic Loop** — AI decides which tools to call, up to 10 steps per turn
- **Persistent Memory** — 2-layer system: curated MEMORY.md + daily append-only notes
- **Hybrid Search** — SQLite FTS5 + vector similarity for finding memories
- **Soul System** — Tamagotchi personality that evolves with you (SOUL.md)
- **Voice Interaction** — ElevenLabs TTS + Apple Speech Recognition
- **Scheduled Tasks** — Cron jobs that run the full agent autonomously
- **Native Apps** — SwiftUI apps for iOS/iPadOS/macOS with fluid Nami entity
- **Smart Model Selection** — Auto-detects API keys, picks best model per tier
- **Multi-Provider** — OpenRouter, OpenAI, Anthropic, Moonshot, Together AI

## Native Apps

NamiOS includes native SwiftUI apps for Apple platforms:

| Platform | Features |
|----------|----------|
| **iOS/iPadOS** | Chat, Voice, Memory browser, OS creations, Nami entity |
| **macOS** | Split view, keyboard shortcuts, system integration |

The Nami entity is a fluid wave shape that:
- Reacts to your voice amplitude
- Responds to touch/gestures
- Shows emotions (happy, thinking, speaking)
- Evolves through XP levels (Ripple → Ocean)

## Quick Start

### Server (Backend)

```bash
# Clone
git clone https://github.com/AlekDob/nami.git
cd nami

# Install dependencies
bun install

# Configure
cp .env.example .env
# Edit .env — set at least one API key

# Run
bun run dev
```

### iOS/macOS App

Open `MeowApp/NamiOS.xcodeproj` in Xcode and run on your device.

## Configuration

Set at least one API key in `.env`:

```env
# Pick one (or more) provider
OPENROUTER_API_KEY=sk-or-v1-...   # Cheapest, most models
OPENAI_API_KEY=sk-...              # Direct OpenAI
MOONSHOT_API_KEY=sk-...            # Kimi K2
TOGETHER_API_KEY=sk-...            # Together AI

# API access
NAMI_API_KEY=your-secret-key       # For REST/WebSocket auth

# Optional: force a model tier
MODEL_PRESET=smart                 # fast | smart | pro

# Optional: Voice
ELEVENLABS_API_KEY=...             # ElevenLabs TTS
```

## Architecture

```
Server (Hetzner)
├── src/
│   ├── agent/          # Core agent loop, system prompt
│   ├── api/            # REST + WebSocket server
│   ├── tools/          # shell, web-fetch, file I/O, email, X
│   ├── memory/         # 2-layer store + SQLite search
│   ├── scheduler/      # Cron engine for autonomous tasks
│   ├── creations/      # Mini web app builder
│   ├── skills/         # Markdown skill loader
│   └── soul/           # Personality system
│
└── data/               # User data (not in git)
    ├── memory/         # MEMORY.md + daily notes
    ├── soul/           # SOUL.md personality
    ├── creations/      # Generated web apps
    └── jobs/           # Scheduler state

iOS/macOS App (SwiftUI)
├── Sources/
│   ├── Core/           # API client, WebSocket, Auth
│   ├── Features/
│   │   ├── Chat/       # Conversation UI
│   │   ├── Nami/       # Entity views, props, stats
│   │   ├── Memory/     # Browser, detail views
│   │   ├── Soul/       # Personality editor
│   │   └── OS/         # Creations gallery
│   └── Shared/         # Theme, components
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Runtime | Bun / Node.js |
| Language | TypeScript (strict), Swift |
| AI SDK | Vercel AI SDK v6 |
| Providers | OpenRouter, OpenAI, Anthropic, Moonshot, Together |
| Search | SQLite FTS5 + sqlite-vec |
| Voice | ElevenLabs TTS, Apple Speech |
| iOS/macOS | SwiftUI, SwiftData, @Observable |

## License

MIT
