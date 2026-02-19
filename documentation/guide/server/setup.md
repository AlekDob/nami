# Setup Guide

## Prerequisites

- **Bun** 1.0+ (primary) or **Node.js** 18+
- API key for at least one provider

## Installation

```bash
cd /root/meow
bun install
```

## Configuration

```bash
cp .env.example .env
```

Edit `.env` with your provider setup:

### Option A: OpenRouter (recommended for cost)

```env
OPENROUTER_API_KEY=sk-or-v1-your-key-here
MODEL_NAME=minimax/minimax-m2.1
```

### Option B: Moonshot (Kimi direct)

```env
PROVIDER=moonshot
MOONSHOT_API_KEY=sk-your-key-here
MODEL_NAME=kimi-k2-0905-preview
```

Available Moonshot models:
- `kimi-k2-0905-preview` — K2, 256K context
- `kimi-k2.5` — K2.5 multimodal, 256K context
- `kimi-k2-thinking` — K2 with reasoning, 256K context
- `kimi-latest` — Latest stable, 131K context

### Option C: Together AI

```env
PROVIDER=together
TOGETHER_API_KEY=your-key-here
MODEL_NAME=moonshotai/Kimi-K2.5
```

### Discord Bot (optional)

```env
DISCORD_TOKEN=your-bot-token
DISCORD_CLIENT_ID=your-client-id
DISCORD_GUILD_ID=your-guild-id
```

## Running

```bash
# Development
bun run dev

# Build binary
bun run build
./bin/meow

# Type check
bun run typecheck
```

## Running as Daemon

To keep NamiOS running 24/7 on the server:

```bash
# Using systemd (recommended)
# Create /etc/systemd/system/meow.service
# Then: systemctl enable meow && systemctl start meow

# Or using screen/tmux
tmux new -s meow
cd /root/meow && bun run dev
# Ctrl+B, D to detach
```

## Troubleshooting

### "Error: Not Found" (404)
- Check model name is correct for your provider
- If using Moonshot/Together: ensure code uses `provider.chat()`
  not `provider()` (see ARCHITECTURE.md gotchas)

### "API key is missing"
- Verify the correct env var is set for your PROVIDER
- Moonshot needs MOONSHOT_API_KEY, not OPENROUTER_API_KEY

### Wrong model responding
- Check PROVIDER and MODEL_NAME match
- Restart the process after changing .env
