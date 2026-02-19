# Architecture

## Overview

NamiOS is an always-on AI personal assistant running on Hetzner.
It uses an agentic loop pattern where the AI model decides which
tools to call, maintains persistent memory, and loads modular skills.

Inspired by [Molt.bot](https://docs.molt.bot) architecture.

## System Architecture

```
                    ┌──────────────────────────────┐
                    │         Channels              │
                    │  CLI  │  Discord  │  (iOS)    │
                    └───────────┬───────────────────┘
                                │
                    ┌───────────▼───────────────────┐
                    │        Agent Loop              │
                    │                                │
                    │  intake → context assembly     │
                    │  → model inference             │
                    │  → tool execution              │
                    │  → response → persistence      │
                    └──┬─────────┬─────────┬────────┘
                       │         │         │
              ┌────────▼──┐ ┌───▼────┐ ┌──▼────────┐
              │   Tools   │ │ Memory │ │  Skills   │
              │           │ │        │ │           │
              │ web-fetch │ │context │ │x-growth   │
              │ file-r/w  │ │learnings│ │email-dgst│
              │ email     │ │people  │ │  ...      │
              │ x-api     │ │sessions│ │           │
              │ shell     │ │        │ │           │
              └────────┬──┘ └───┬────┘ └──┬────────┘
                       │        │         │
              ┌────────▼────────▼─────────▼────────┐
              │           Scheduler                 │
              │  cron jobs → trigger agent tasks     │
              └────────────────┬───────────────────┘
                               │
              ┌────────────────▼───────────────────┐
              │        Model Providers              │
              │  OpenRouter │ Moonshot │ Together   │
              └────────────────────────────────────┘
```

## Core Components

### Agent Loop (src/agent/agent.ts)

The heart of NamiOS. Uses Vercel AI SDK v6 `generateText()` with tools:

```ts
const result = await generateText({
  model: getModel(),
  system: systemPrompt + memoryContext + skillContext,
  messages: conversationHistory,
  tools: registeredTools,
  maxSteps: 10,
});
```

The model autonomously decides which tools to call per turn.
maxSteps allows multi-step reasoning (call tool → read result → call another).

### Tools (src/tools/)

Tools the agent can invoke during reasoning:

| Tool | Purpose |
|------|---------|
| web-fetch | Fetch and read web pages |
| file-read | Read files on the server |
| file-write | Write/create files |
| email-read | Read email via IMAP |
| x-api | Twitter/X API integration |
| shell-exec | Execute shell commands |
| memory-save | Save to persistent memory |
| memory-search | Search persistent memory |

Each tool is defined with Zod schema for parameters and an
async execute function.

### Memory (src/memory/)

File-based persistent memory, similar to Quack Brain:

```
data/memory/
├── context.md      # Who the user is, preferences
├── learnings.md    # Things learned over time
├── people.md       # People and relationships
└── sessions/
    └── YYYY-MM-DD.md  # Daily session logs
```

Memory is loaded into the system prompt at context assembly time.
The agent can write new memories via the memory-save tool.

### Skills (src/skills/)

Modular capability packs loaded as markdown files:

```
data/skills/
├── x-growth.md       # X/Twitter growth advisor
├── email-digest.md   # Email summarization
└── ...
```

Each skill file contains a system prompt extension and
optionally specifies which tools it needs.

### Channels (src/channels/)

Communication interfaces:

- **CLI** (src/channels/cli.ts) — Interactive terminal with ASCII cat
- **Discord** (src/channels/discord.ts) — Bot with slash commands
- **iOS** (future) — Native app or PWA

### Scheduler (src/scheduler/)

Cron-like job engine that triggers agent tasks:

- Email digest every morning
- X/Twitter monitoring hourly
- Custom scheduled tasks

### Config (src/config/)

Environment-based configuration:

| Variable | Purpose |
|----------|---------|
| PROVIDER | "moonshot" / "together" / empty (OpenRouter) |
| MODEL_NAME | Model identifier for chosen provider |
| OPENROUTER_API_KEY | OpenRouter API key |
| MOONSHOT_API_KEY | Moonshot/Kimi API key |
| TOGETHER_API_KEY | Together AI API key |
| DISCORD_TOKEN | Discord bot token |

## Model Providers

| Provider | Use Case | Cost |
|----------|----------|------|
| OpenRouter | Default, cheapest routing | ~$0.40/M tokens (MiniMax) |
| Moonshot | Kimi K2 direct | Free tier available |
| Together AI | Alternative hosting | Varies |

**Important**: For Moonshot/Together, use `provider.chat(modelName)`
to force Chat Completions endpoint. See gotchas below.

## Known Gotchas

1. AI SDK v6 defaults to `/v1/responses` — non-OpenAI providers need `.chat()`
2. API keys must route through `getApiKey()` — don't hardcode fallbacks
3. Model names differ across providers — check provider docs

## Runtime

Bun is the primary runtime (faster, native TS).
Node.js is supported as fallback.

```ts
import { detectRuntime, isBun } from './utils/runtime';
```
