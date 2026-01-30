# Usage Guide

## CLI Interactive Mode

```bash
bun run dev
```

### Interface

The CLI shows an animated ASCII cat on startup, then a prompt:

```
  You > your message here
  Meow > AI response
```

### Commands

| Command | Description |
|---------|-------------|
| `/model` | Show current model |
| `/model name` | Switch model at runtime |
| `/clear` | Clear screen |
| `/exit` | Quit |

### Examples

```
> leggi le mie ultime email e fammi un riassunto
  (agent calls email-read tool, then summarizes)

> cosa si dice su X riguardo Claude Code?
  (agent calls x-api tool, analyzes results)

> salva che domani ho una call con Marco alle 15
  (agent calls memory-save tool)
```

## Model Selection

Switch models at runtime with `/model`:

```
> /model kimi-k2.5
  Model changed to: kimi-k2.5

> /model minimax/minimax-m2.1
  Model changed to: minimax/minimax-m2.1
```

### Model Reference

| Provider | Model | Cost | Best For |
|----------|-------|------|----------|
| OpenRouter | minimax/minimax-m2.1 | ~$0.40/M | Daily tasks, cheap |
| Moonshot | kimi-k2-0905-preview | Free tier | General, 256K context |
| Moonshot | kimi-k2.5 | Low | Multimodal, coding |
| Moonshot | kimi-k2-thinking | Low | Complex reasoning |
| OpenRouter | anthropic/claude-sonnet | ~$3/M | High quality |

## Scheduled Jobs

Jobs run automatically via the scheduler:

| Job | Schedule | Description |
|-----|----------|-------------|
| email-digest | Daily 8:00 | Summarize unread emails |
| x-monitor | Hourly | Check X mentions and trends |

## Discord Bot

(Coming soon)

Commands:
- `/ask question` — Ask the agent
- `/status` — Agent status and memory stats
- `/jobs` — List scheduled jobs

## Memory

The agent remembers context across sessions.
Memory is stored in `data/memory/` as markdown files.

The agent automatically:
- Loads relevant memory into context
- Saves important learnings
- Maintains daily session logs

## Skills

Skills extend the agent's capabilities.
Located in `data/skills/` as markdown files.

Available skills:
- **x-growth** — X/Twitter growth advisor with API access
- **email-digest** — Email summarization and triage

## File Locations

| Path | Purpose |
|------|---------|
| /root/meow/src/ | Source code |
| /root/meow/data/memory/ | Persistent memory |
| /root/meow/data/skills/ | Skill definitions |
| /root/meow/data/jobs/ | Job state |
| /root/meow/.env | Configuration |
