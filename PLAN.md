# PLAN.md — Meow Implementation Plan

> Full briefing for any agent implementing meow.
> Read AGENTS.md first for project context, then this file for the plan.

## What We're Building

Meow is an **always-on AI personal assistant** that:
- Runs 24/7 as a daemon on Hetzner (Ubuntu 4GB, ssh root@ubuntu-4gb-hel1-1)
- Uses an **agentic loop**: model receives tasks, decides which tools to call,
  executes them, reasons on results, and responds
- Has **persistent memory** with 2-layer storage + SQLite hybrid search
- Loads **modular skills** from markdown files (like x-growth-advisor for Twitter)
- Connects via multiple **channels**: CLI (done), Discord (planned), iOS (future)
- Uses **cheap models** (Kimi via Moonshot, MiniMax via OpenRouter) to keep costs
  at cents per day
- Is designed as a **multi-user product**, not a personal tool

Inspired by [Molt.bot](https://docs.molt.bot) architecture + [Clawdbot](https://manthanguptaa.in) memory system.

## Current State

### ✅ Phase 1 — COMPLETE

- CLI with animated ASCII cat, colored UI (src/cli.ts)
- Agent class with provider routing: OpenRouter, Moonshot, Together (src/agent/agent.ts)
- System prompt builder with memory context injection (src/agent/system-prompt.ts)
- Config loading from env vars (src/config/)
- Runtime detection Bun/Node (src/utils/runtime.ts)
- 5 core tools: web-fetch, file-read, file-write, memory-search, memory-get
- 2-layer memory system with SQLite hybrid search (Clawdbot-inspired)
- Multi-step tool use (stopWhen: stepCountIs(10))

### ✅ Phase 2 — COMPLETE

- Scheduler with cron expressions + interval runner (src/scheduler/)
- IMAP email reader tool (src/tools/email-read.ts)
- 3 X/Twitter API tools: timeline, search, mentions (src/tools/x-api.ts)
- Job persistence to data/jobs/jobs.json

### ✅ Memory System Overhaul — COMPLETE

Migrated from simple file-append to Clawdbot-inspired 2-layer system:
- Layer 1: `daily/YYYY-MM-DD.md` — append-only daily notes
- Layer 2: `MEMORY.md` — curated long-term knowledge
- SQLite indexer with FTS5 (BM25) + sqlite-vec (vector similarity)
- Hybrid scoring: `0.7 * vectorScore + 0.3 * keywordScore`, minScore 0.35
- Optional OpenAI embeddings (text-embedding-3-small, ~$0.001/day)
- No `memorySave` tool — agent writes to memory via standard `fileWrite`
- Chunking: ~1200 chars with 200 char overlap

### ✅ Phase 3 — COMPLETE

- Pre-compaction memory flush (src/agent/flush.ts)
- Skill system with YAML frontmatter loader (src/skills/)
- Discord bot with slash commands (src/channels/discord.ts)
- CLI DRY refactor: split into 3 modules (src/cli/)
- Tool-use animation in CLI (magenta, auto-labeled)

### ✅ Smart Model Selection — COMPLETE

Auto-selects the best available model based on API keys and preset:
- 3 presets: fast (Gemini Flash, Kimi K2), smart (GPT-4o Mini), pro (GPT-4o, Claude 3.5 Sonnet)
- Prefers models with tool-use capability
- CLI commands: `/models` (list), `/model` (switch)
- `src/config/models.ts` — Model registry with `pickBestModel()`, `findModel()`, `createModel()` (136 lines)

### ✅ MEMORY.md Overwrite Protection — COMPLETE

Fixed critical bug where models overwrote MEMORY.md instead of updating it:
- `fileWrite` now merges sections by `## Heading` when writing to `*memory.md`
- New sections added, existing sections updated, missing sections preserved
- `src/tools/file-write.ts` — `mergeMemory()` + `parseSections()` (103 lines)

### ✅ Soul System — COMPLETE

Per-user personality system (tamagotchi concept):
- `data/soul/SOUL.md` — Defines the cat's personality, traits, voice, backstory
- First-run onboarding: cat introduces itself, asks user to define personality
- Injected into system prompt as "Your Soul" — agent embodies it in every response
- User can change personality anytime via natural language
- `src/soul/soul.ts` — SoulLoader class (88 lines)

### ⏳ Pending

- Phase 4: Packaging + Distribution
- Phase 5: Hardware / iOS

**Codebase stats**: 29 TypeScript files, 2612 lines total.


### Scheduled Tasks System -- DONE

- **scheduleTask tool**: Agent can schedule any task (reminders + autonomous actions) via tool call
- **Time parsing**: Supports "17:00", "in 30m", "in 2h", full cron expressions
- **One-time and recurring**: repeat=true for daily/weekly, false for one-shot
- **CLI notifications**: Yellow ASCII cat alert when reminder fires
- **Scheduler upgrade**: setTimeout-based with real cron parsing (not just intervals)
- **3 tools**: scheduleTask, listTasks, cancelTask
- Files: src/tools/schedule-reminder.ts (142 lines), src/scheduler/cron.ts (179 lines)

## Tech Stack

- Runtime: Bun (primary)
- Language: TypeScript strict, no `any`
- AI: Vercel AI SDK v6 (`ai` package), `generateText()` with `tools` + `stopWhen`
- Providers: `@openrouter/ai-sdk-provider`, `@ai-sdk/openai` (for Moonshot/Together)
- Validation: Zod (for tool parameters)
- Search: SQLite with FTS5 + sqlite-vec (hybrid semantic + keyword)
- Discord: discord.js v14 (Phase 3)

## Phase 1 — Agent Loop with Tools + Memory ✅ DONE

### 1.1 Agent refactor ✅

Refactored agent.ts for full agentic loop with:
- `ModelMessage[]` conversation history
- Dynamic system prompt from base + memory context
- Tool registry with all registered tools
- `stopWhen: stepCountIs(10)` for multi-step reasoning
- Per-userId scoping (multi-user ready)

### 1.2 Core tools ✅

| Tool | File | Description |
|------|------|-------------|
| webFetch | src/tools/web-fetch.ts | Fetch URL, return text (truncated) |
| fileRead | src/tools/file-read.ts | Read file from data/ (sandboxed) |
| fileWrite | src/tools/file-write.ts | Write file to data/ (sandboxed, auto-mkdir) |
| memorySearch | src/tools/memory-search.ts | Hybrid search across memory files |
| memoryGet | src/tools/memory-get.ts | Read specific lines from memory files |

Tool registry in src/tools/index.ts: `coreTools` (static) + `buildTools(memory)` (dynamic).

### 1.3 Memory store ✅ (Clawdbot-inspired)

2-layer system:

```
data/memory/{userId}/
├── MEMORY.md              # Layer 2: curated long-term knowledge
├── daily/
│   ├── 2026-01-30.md      # Layer 1: daily notes (append-only)
│   └── ...
└── index.sqlite           # Vector + FTS5 index (auto-generated)
```

Key files:
- `src/memory/types.ts` — MemoryConfig, SearchResult, Chunk interfaces (53 lines)
- `src/memory/store.ts` — MemoryStore class (188 lines)
- `src/memory/indexer.ts` — SQLite FTS5 + sqlite-vec indexer (265 lines)
- `src/memory/embeddings.ts` — Optional OpenAI embedding provider (50 lines)

Config defaults:
- memoryMaxBytes: 4096, dailyTailCount: 10
- vectorWeight: 0.7, keywordWeight: 0.3, minScore: 0.35
- chunkSize: 1200, chunkOverlap: 200

### 1.4 System prompt ✅

Clawdbot-inspired prompt with:
- 2-layer memory instructions (daily = transient, MEMORY.md = durable)
- "Search before answering" rule for memory recall
- Quality gate (Claudeception): only save genuine discoveries
- Language auto-detection

## Phase 2 — Scheduler + External Tools ✅ DONE

### 2.1 Cron engine ✅

`src/scheduler/cron.ts` — Job CRUD + interval runner.
Jobs in `data/jobs/jobs.json`. Supports @hourly, @daily, @weekly presets.

### 2.2 Email tool ✅

`src/tools/email-read.ts` — IMAP via imapflow. Reads inbox, filters unread.

### 2.3 X/Twitter tools ✅

`src/tools/x-api.ts` — 3 tools using Twitter API v2:
- xGetTimeline, xSearchTweets, xGetMentions

## Phase 3 — Skill System + Discord + Flush ✅ DONE

### 3.1 Skill loader ✅

Load .md files from data/skills/ that extend the system prompt:

```yaml
---
name: x-growth-advisor
description: Twitter/X growth strategy advisor
tools: [xApi, webFetch]
schedule: "0 9 * * *"
---

You are an X/Twitter growth advisor...
```

YAML frontmatter configures the skill, body extends system prompt.

### 3.2 Discord bot ✅

Bot commands:
- /ask [message] — Send a message to the agent
- /status — Agent status, memory stats, active jobs
- /jobs — List and manage scheduled jobs
- /skills — List active skills
- /memory [query] — Search agent memory

## Phase 4 — Packaging + Distribution

Meow is self-hosted: each user installs their own instance on their server.
No multi-user auth needed — the user owns the entire instance.

### 4.1 README + Quick Start
- Clear README with prerequisites (Bun, API key)
- One-liner install:  +  + 
- Example .env.example with all supported keys documented

### 4.2 Setup Wizard (CLI)
- Interactive first-run wizard: asks for API keys, preferred model preset
- Validates API keys before saving
- Creates .env automatically
- Triggers Soul onboarding after setup

### 4.3 Docker Support
- Dockerfile (Bun-based, slim image)
- docker-compose.yml with volume mounts for data/
- Environment variable passthrough for API keys

### 4.4 Config Validation
- Validate .env on startup (missing keys, invalid formats)
- Friendly error messages: "Missing OPENROUTER_API_KEY — get one at openrouter.ai"
- Warn if no tool-capable model is available

### 4.5 Distribution
- npm package (npx meow-ai)
- GitHub release with install script
- Version tagging + changelog

## Phase 5 — Hardware / iOS (Future)

- REST API endpoint for external clients
- iOS app or PWA for mobile access
- DeskHog ESP32 thin client (optional)
- Raspberry Pi 5 as alternative host

## Critical Gotchas

1. **AI SDK v6 renames**: `CoreMessage` → `ModelMessage`, `parameters` → `inputSchema`,
   `maxSteps` → `stopWhen: stepCountIs(N)`

2. **AI SDK v6 endpoint routing**: non-OpenAI providers need `provider.chat(modelName)`
   to force /v1/chat/completions

3. **API key routing**: getModel() must call getApiKey() per provider

4. **Model names differ**: kimi-k2-0905-preview (Moonshot) vs moonshotai/kimi-k2.5 (OpenRouter)

5. **sqlite-vec**: Requires `bun:sqlite` + sqlite-vec extension (v0.1.7-alpha.2)

6. **Bun PATH**: Binary at `/root/.bun/bin/bun`

7. **MEMORY.md overwrite protection**: `fileWrite` merges sections for `*memory.md` files to prevent data loss

8. **Kimi K2 tool use**: Kimi K2 doesn't reliably call tools. Use `smart` preset (GPT-4o Mini) for reliable tool use

9. **Soul onboarding**: First run without SOUL.md triggers onboarding mode — cat asks user to define personality

## Design Rules

1. **DRY** — extract shared logic, never duplicate
2. **Feature-oriented** — organize by domain, not tech layer
3. **Self-hosted** — each user owns their instance, no shared auth needed
4. **Extensible** — common interfaces (ToolDefinition, Channel, MemoryStore)
5. **Functions max 20 lines, files max 300 lines**
6. **TypeScript strict, no `any`, Zod for validation**
7. **English for code/docs, Italian for UI strings**
8. **Memory = plain markdown** — agent writes via fileWrite, no special tool
