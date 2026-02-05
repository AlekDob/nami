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
- **Smart Model Selection** — Auto-detects API keys, picks best model per tier
- **Multi-Provider** — OpenRouter, OpenAI, Anthropic, Moonshot, Together AI

## Native Apps 📱

Native SwiftUI apps for iOS/iPadOS/macOS are available in a **separate private repository** for collaborators and clients.

**Features include:**
- Chat with real-time WebSocket
- OS section for viewing Nami's creations
- Memory browser with offline cache
- Jobs scheduler CRUD
- Soul/personality editor
- Nami entity with fluid animations
- Voice: ElevenLabs TTS + Apple Speech Recognition

> **Interested in the native app?** [Contact us](mailto:alek@alekdob.com) for access or check out our [services](#services).

## Quick Start

### One-Line Install (Recommended)

```bash
npx create-namios@latest
```

Or directly from GitHub:

```bash
npx github:AlekDob/create-namios
```

This will:
1. Download NamiOS
2. Install dependencies
3. Run interactive configuration
4. Set up your `.env` file

Then start:

```bash
cd namios
nami start    # Start daemon
nami          # Interactive CLI
```

### Manual Install

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

### CLI Commands

```bash
nami start     # Start daemon (background)
nami stop      # Stop daemon
nami status    # Check status
nami logs      # View logs
nami           # Interactive chat
```

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
Server
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
```

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Runtime | Bun / Node.js |
| Language | TypeScript (strict) |
| AI SDK | Vercel AI SDK v6 |
| Providers | OpenRouter, OpenAI, Anthropic, Moonshot, Together |
| Search | SQLite FTS5 + sqlite-vec |
| Voice | ElevenLabs TTS |

## Services

Need help setting up NamiOS or want custom features? We offer:

| Service | Description |
|---------|-------------|
| **Setup Assistance** | We deploy and configure NamiOS on your server |
| **Custom Features** | Integrations, new tools, custom UI |
| **Managed Hosting** | We handle everything, you just use it |
| **Training** | Learn to customize and extend NamiOS |

📧 **Contact:** [alek@alekdob.com](mailto:alek@alekdob.com)

## License

MIT — The backend is fully open source. Use it, modify it, contribute!

---

<p align="center">
  <i>Made with 🌊 in Puglia, Italy</i>
</p>
