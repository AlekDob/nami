---
type: gotcha
project: namios
created: 2026-02-12
tags: [mcp, mixpanel, cli, configuration, token, stdio]
---

# Gotcha: Mixpanel MCP Server Token Configuration

## The Issue
Mixpanel MCP server (`mixpanel-mcp-server` v2.0.1) requires the token as a **CLI argument** (`--token <value>`), not as an environment variable. Additionally, the command must be `npx -y`, not `bun -y`.

## The Mistake
Initial `.mcp.json` configuration:

```json
{
  "type": "command",
  "command": "bun",
  "args": ["-y", "mixpanel-mcp-server"],
  "env": {
    "MIXPANEL_PROJECT_TOKEN": "d216030c..."
  }
}
```

This fails because:
1. **Bun doesn't support `-y` flag** — That's an `npx` flag for automatic yes-to-all
2. **Server expects CLI arg** — It reads `--token` from args, not `MIXPANEL_PROJECT_TOKEN` from env
3. **Silent failure** — The server process starts but fails to initialize, with error only visible in stdout logs

## The Solution
Pass the token as a CLI argument:

```json
{
  "type": "command",
  "command": "npx",
  "args": ["-y", "mixpanel-mcp-server", "--token", "d216030c..."]
}
```

This works because:
- `npx` is the npm package runner that understands `-y` (auto-yes)
- `--token` is the expected CLI argument for Mixpanel server
- Server initializes successfully and returns MCP response

## Verification
Test directly before integrating into `.mcp.json`:

```bash
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{...}}' | npx -y mixpanel-mcp-server --token d216030c...
```

Expected response:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2024-11-05",
    "capabilities": {...},
    "serverInfo": {
      "name": "mixpanel-mcp-server",
      "version": "2.0.1"
    }
  }
}
```

## Key Insight
**Different MCP servers have different token delivery methods:**

| Server | Token Method | Example |
|--------|--------------|---------|
| Mixpanel | CLI `--token` | `mixpanel-mcp-server --token <TOKEN>` |
| PostHog | HTTP header | `Authorization: Bearer <TOKEN>` |
| Custom tools | Env var (common) | `CUSTOM_API_KEY=<TOKEN> custom-tool` |

Always check the server's documentation or test the stdio command directly before integrating. Environment variable assignment doesn't always work for every tool.

## Trigger Conditions
- Configuring a new stdio-based MCP server
- Getting silent MCP connection failures with command-based servers
- Debugging "server failed to initialize" errors
- Adding Mixpanel or similar CLI-based tools

## Prevention Checklist
- [ ] Test the stdio command directly with `printf` + `|` before adding to `.mcp.json`
- [ ] Check server's README for token/auth configuration method (CLI arg vs env var)
- [ ] Use `npx` for npm-based MCP servers, not `bun`
- [ ] Monitor service logs: `systemctl status meow` or tail `-f` on stdout
- [ ] If integration fails, try the command in shell first to see actual error
