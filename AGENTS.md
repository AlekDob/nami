# AGENTS.md — Meow Project Context

> This file provides context for any AI agent working on this codebase.
> Read this before making changes.

## Project Vision

Meow is a **self-hosted AI assistant** — each user installs their own instance.
Every decision should favor simplicity and ease of self-hosting.
No shared auth or multi-tenancy needed.

## Project Overview

**Meow** is an always-on AI personal assistant running on Hetzner (4GB Ubuntu).
It uses an agentic loop pattern: the AI model receives tasks, decides which
tools to call, maintains persistent memory, and loads modular skills.

Built with Vercel AI SDK v6. Inspired by Molt.bot architecture.

## Design Principles

### 1. DRY — Don't Repeat Yourself
- Extract shared logic into reusable modules immediately
- If you write the same pattern twice, abstract it
- Tools, skills, and channels must share common interfaces
- One source of truth for config, types, and constants

### 2. Feature-Oriented Architecture
- Organize code by domain/feature, NOT by technical layer
- Each feature is self-contained: its routes, logic, types, and tests together
- A new tool = one folder with everything it needs
- A new channel = one folder, plug and play

Bad:
    src/types/    ← all types dumped together
    src/utils/    ← grab bag of helpers
    src/services/ ← everything else

Good:
    src/tools/email/
    ├── email-read.ts     # Tool implementation
    ├── email-send.ts     # Send capability
    ├── email.types.ts    # Email-specific types
    └── email.test.ts     # Tests

### 3. Self-Hosted by Design
- Each user owns their entire instance — no shared auth needed
- Simple setup: clone, configure .env, run
- Data lives on the user's own server (data/ directory)
- Skills and memory are local to the instance
- Docker support for easy deployment

### 4. Extensibility Over Customization
- New tools = implement a ToolDefinition interface, register, done
- New channels = implement a Channel interface, register, done
- New skills = drop a .md file in the skills folder
- New providers = add a case in getModel(), nothing else changes

## Tech Stack

| Layer      | Technology                          |
|------------|-------------------------------------|
| Runtime    | Bun (primary), Node.js (fallback)   |
| Language   | TypeScript (strict)                 |
| AI SDK     | Vercel AI SDK v6 (ai package)       |
| Providers  | OpenRouter, Moonshot, Together AI   |
| Discord    | discord.js v14                      |
| Validation | Zod                                 |
| Server     | Hetzner 4GB Ubuntu (ssh root@ubuntu-4gb-hel1-1) |

## Architecture

**29 TypeScript files, ~2612 lines total.**

    src/
    ├── agent/
    │   ├── agent.ts            # Agent loop — generateText() with tools + maxSteps (160 lines, loads Soul)
    │   ├── system-prompt.ts    # System prompt builder — injects soul + onboarding context
    │   └── memory.ts           # Memory manager — loads/saves persistent memory
    ├── cli/                    # CLI channel — split into 3 files
    │   ├── index.ts            # CLI entry point / orchestrator
    │   ├── ui.ts               # Animated ASCII cat + display logic
    │   └── commands.ts         # Slash-command handler (/models, /model, etc.)
    ├── tools/                  # Tools the agent can invoke (each self-contained)
    │   ├── web-fetch.ts        # Fetch and read web pages
    │   ├── file-read.ts        # Read files on server
    │   ├── file-write.ts       # Write/create files (MEMORY.md merge protection)
    │   ├── email-read.ts       # IMAP email reading
    │   ├── x-api.ts            # Twitter/X API
    │   ├── shell-exec.ts       # Execute shell commands
    │   ├── memory-search.ts    # Hybrid search tool
    │   ├── memory-get.ts       # Line-range reader tool
    │   └── schedule-reminder.ts # Scheduled task tools (schedule/list/cancel actions + reminders) — 142 lines
    ├── skills/                 # Modular skill loader
    │   └── loader.ts           # Loads .md skill files from data/skills/
    ├── soul/
    │   └── soul.ts             # SoulLoader — tamagotchi personality system
    ├── memory/                 # Persistent memory store
    │   ├── store.ts            # File-based memory (markdown files)
    │   ├── indexer.ts          # SQLite FTS5 + sqlite-vec indexer
    │   ├── embeddings.ts       # Optional OpenAI embedding provider
    │   └── types.ts            # Memory entry types
    ├── scheduler/              # Cron job engine
    │   └── cron.ts             # Triggers agent tasks on schedule
    ├── channels/               # Communication interfaces
    │   ├── cli.ts              # Terminal interface (done)
    │   └── discord.ts          # Discord bot (planned)
    ├── config/
    │   ├── index.ts            # Loads config from env vars
    │   ├── models.ts           # Smart Model Selection — presets + auto-detect (136 lines)
    │   └── types.ts            # TypeScript interfaces
    └── utils/
        └── runtime.ts          # Bun/Node runtime detection

    data/
    ├── memory/{userId}/    # Per-user persistent memory
    │   ├── MEMORY.md       # Curated long-term knowledge
    │   ├── daily/          # Append-only daily notes
    │   └── index.sqlite    # Vector + FTS5 search index
    ├── soul/
    │   └── SOUL.md         # Per-user personality (tamagotchi)
    ├── skills/             # Skill definition files (.md)
    └── jobs/               # Scheduler state persistence

## Agent Loop Pattern

    intake → context assembly → model inference → tool execution → response → persistence

The agent uses AI SDK's generateText() with tools and maxSteps:
- Model decides which tools to call autonomously
- Up to maxSteps tool calls per turn
- Memory loaded into system prompt at context assembly
- Soul personality injected into system prompt as "Your Soul"
- New learnings saved after each interaction

## Provider Setup

### OpenRouter (default, cheapest)
    OPENROUTER_API_KEY=sk-or-v1-...
    MODEL_NAME=minimax/minimax-m2.1

### Moonshot (Kimi direct)
    PROVIDER=moonshot
    MOONSHOT_API_KEY=sk-...
    MODEL_NAME=kimi-k2-0905-preview

Available: kimi-k2-0905-preview, kimi-k2.5, kimi-k2-thinking, kimi-latest

### Together AI
    PROVIDER=together
    TOGETHER_API_KEY=...
    MODEL_NAME=moonshotai/Kimi-K2.5

## Smart Model Selection

Three presets for different tasks, configured in `src/config/models.ts` (136 lines):

| Preset  | Use Case                     | Behavior                        |
|---------|------------------------------|---------------------------------|
| `fast`  | Quick answers, simple tasks  | Cheapest available model        |
| `smart` | Default — tool use, reasoning| Best tool-capable model         |
| `pro`   | Complex analysis, planning   | Most capable model available    |

- **Auto-detect API keys**: scans env for available providers and picks the best model per preset
- **Prefer tool-use capable models**: filters out models known to have poor tool calling
- **CLI commands**: `/models` lists available presets, `/model <preset>` switches active model

## Memory System

Clawdbot-inspired 2-layer design with SQLite hybrid search. Per-user scoped.

    data/memory/{userId}/
    ├── MEMORY.md              # Layer 2: curated long-term knowledge
    ├── daily/
    │   └── YYYY-MM-DD.md     # Layer 1: append-only daily notes
    └── index.sqlite           # Vector + FTS5 search index

**Layer 1 (daily/)**: Append-only notes the agent writes throughout the day.
**Layer 2 (MEMORY.md)**: Curated persistent knowledge (preferences, decisions, contacts).

No dedicated `memorySave` tool — agent writes via standard `fileWrite`.
Search is hybrid: `0.7 * vectorScore + 0.3 * keywordScore` using SQLite FTS5 + sqlite-vec.
Optional OpenAI embeddings (text-embedding-3-small) for semantic search.

Key files:
- `src/memory/store.ts` — 2-layer MemoryStore (188 lines)
- `src/memory/indexer.ts` — SQLite FTS5 + sqlite-vec indexer (265 lines)
- `src/memory/embeddings.ts` — Optional OpenAI embedding provider (50 lines)
- `src/memory/types.ts` — MemoryConfig, SearchResult, Chunk (53 lines)
- `src/tools/memory-search.ts` — Hybrid search tool
- `src/tools/memory-get.ts` — Line-range reader tool

## Soul System

Tamagotchi-inspired personality system that gives each user's Meow a unique character.

    data/soul/SOUL.md          # Per-user personality file

- **First-run onboarding**: On first launch (no SOUL.md exists), Meow triggers an onboarding flow to learn the user's name, preferences, and communication style, then generates SOUL.md
- **Injected into system prompt**: The soul content is loaded by `SoulLoader` (`src/soul/soul.ts`) and injected into the system prompt under a "Your Soul" section via `src/agent/system-prompt.ts`
- **Editable via fileWrite**: The agent can update its own personality over time through the standard `fileWrite` tool
- **Per-user scoped**: Each user gets their own SOUL.md, keeping personalities isolated

## Skills System

Markdown files in data/skills/ that extend the system prompt:
- Each skill defines a specialized capability
- Can specify which tools it needs
- Loaded dynamically at context assembly time
- Global skills (available to all users) and per-user skills

## Critical Gotchas

1. **AI SDK v6 endpoint issue**: provider(modelName) hits /v1/responses (OpenAI only).
   For Moonshot/Together, MUST use provider.chat(modelName) to force /v1/chat/completions.

2. **API key routing**: getModel() must call getApiKey() for correct key per provider.
   Never hardcode OPENROUTER_API_KEY as fallback for all providers.

3. **Model names differ by provider**: kimi-k2-0905-preview (Moonshot) vs
   moonshotai/kimi-k2.5 (OpenRouter) vs moonshotai/Kimi-K2.5 (Together).

4. **MEMORY.md overwrite protection**: `fileWrite` merges sections when writing to
   MEMORY.md instead of overwriting — prevents accidental loss of curated knowledge.

5. **Kimi K2 doesn't reliably call tools**: Kimi K2 has inconsistent tool-calling behavior.
   Prefer the `smart` preset which selects models known to handle tools well.

6. **Soul System onboarding triggers on first run**: When no SOUL.md exists for a user,
   the agent enters onboarding mode automatically. Don't skip this — it creates the
   personality file needed for subsequent sessions.

## Coding Standards

- **DRY**: extract, don't duplicate. If it exists, reuse it.
- **Feature-oriented**: colocate related code, not by tech layer
- **Self-hosted**: simple setup, no multi-tenant complexity
- **Interfaces first**: define contracts (ToolDefinition, Channel, MemoryStore)
  before implementations — makes extending trivial
- Functions: max 20 lines
- Files: max 300 lines
- Naming: verbNoun for functions, PascalCase for types
- English for code/docs, Italian for UI strings
- Use Zod for all parameter validation
- No `any` — TypeScript strict mode always

## Implementation Phases

1. Agent loop with tools + memory (foundation) — **DONE**
2. Scheduler + first jobs (email digest, X monitoring) — **DONE**
3. Skill system + Discord bot — **DONE**
4. Packaging + Distribution (README, Docker, setup wizard)
5. Hardware / iOS (future)

**Completed extras:**
- Memory Overhaul (2-layer + SQLite hybrid search) — **DONE**
- CLI Refactor (split into ui.ts, commands.ts, index.ts) — **DONE**
- Smart Model Selection (3 presets, auto-detect) — **DONE**
- Soul System (tamagotchi personality + onboarding) — **DONE**
- Reminder System (scheduleTask + CLI/Discord notifications) — **DONE**

## Development

    bun install          # Install deps
    bun run dev          # Start dev mode
    bun run build        # Compile to bin/meow
    bun run typecheck    # TypeScript check
    bun test             # Run tests
