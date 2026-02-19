---
type: gotcha
project: namios
created: 2026-02-12
tags: [mcp, configuration, http, stdio, transport, debugging]
---

# Gotcha: MCP Configuration Pattern Differences (HTTP vs Stdio)

## The Issue
HTTP and stdio MCP servers require different configuration patterns in `.mcp.json`. Mixing them up results in silent failures — MCP servers fail to connect but the app doesn't crash.

## Configuration Patterns

### HTTP Transport (Cloud-Based Servers)

```json
{
  "type": "http",
  "url": "https://mcp-api.example.com/mcp",
  "headers": {
    "Authorization": "Bearer ${POSTHOG_API_KEY}",
    "Content-Type": "application/json"
  }
}
```

**Features:**
- `type: "http"` — Uses `StreamableHTTPClientTransport`
- `url` — Full HTTPS endpoint (required)
- `headers` — Supports `${ENV_VAR}` placeholder substitution
- Auth goes in headers (Bearer token, API key)
- Good for: PostHog, Claude MCP servers, any hosted service

### Stdio Transport (Command-Based Servers)

```json
{
  "type": "command",
  "command": "npx",
  "args": ["-y", "mixpanel-mcp-server", "--token", "${MIXPANEL_TOKEN}"],
  "env": {
    "NODE_ENV": "production"
  }
}
```

**Features:**
- `type: "command"` — Uses `StdioClientTransport`
- `command` — Executable name (npx, bun, python, etc.)
- `args[]` — Command arguments (token can go here!)
- `env` — Optional environment variables (JSON-RPC still uses stdin/stdout)
- Auth can go in args or env (check server's docs!)
- Good for: Mixpanel, local tools, npm-based servers

## The Gotcha: Silent Failures

When configuration is wrong, MCP servers fail silently:

**HTTP Example (Wrong):**
```json
{
  "type": "http",
  "url": "https://posthog.example.com",
  "headers": {
    "Authorization": "Bearer phx_invalid_key_12345"
  }
}
```

Result:
```
[MCP] posthog failed: Cloudflare 1101 Worker threw exception
```
Message appears in logs, but the app continues. The agent just can't use PostHog tools.

**Stdio Example (Wrong):**
```json
{
  "type": "command",
  "command": "bun",
  "args": ["-y", "mixpanel-mcp-server"],
  "env": { "MIXPANEL_TOKEN": "..." }
}
```

Result:
```
[MCP] mixpanel failed: initialize response did not contain server info
```
Bun doesn't support `-y`, npx not found, or token not recognized. Same silent failure.

## How to Debug
1. **Check service logs**:
   ```bash
   ssh root@ubuntu-4gb-hel1-1
   systemctl status meow
   # or tail -f on stdout from tmux session
   ```

2. **Test HTTP manually**:
   ```bash
   curl -X POST "https://api.example.com/mcp" \
     -H "Authorization: Bearer ${API_KEY}" \
     -H "Accept: application/json, text/event-stream" \
     -d '{"jsonrpc":"2.0","id":1,"method":"initialize",...}'
   ```

3. **Test stdio manually**:
   ```bash
   printf '{"jsonrpc":"2.0","id":1,"method":"initialize",...}' | npx -y mixpanel-mcp-server --token ${TOKEN}
   ```

## Prevention Checklist

### Before Adding to `.mcp.json`

- [ ] **Identify transport type**: Cloud (HTTP) or local command (stdio)?
- [ ] **HTTP servers**: Test with curl first, verify endpoint returns valid MCP response
- [ ] **Stdio servers**: Test with printf + pipe, confirm command exists and args are correct
- [ ] **Token placement**: Check server's README for token delivery (CLI arg vs env var vs header)
- [ ] **Environment variable substitution**: Verify `${VAR}` placeholders exist in `.env`
- [ ] **Command availability**: For stdio, ensure `npx` or other command is in PATH
- [ ] **Restart service**: `systemctl restart meow` after `.mcp.json` changes

### After Integration

- [ ] Check logs for `[MCP] <name> connected` message
- [ ] Verify tools appear in agent context: `GET /api/status`
- [ ] Test a tool call: `POST /api/chat` with tool use

## Key Insights

**HTTP vs Stdio at a glance:**

| Aspect | HTTP | Stdio |
|--------|------|-------|
| **Config type** | `"http"` | `"command"` |
| **Where auth goes** | `headers` | `args` or `env` |
| **Env var syntax** | `${VAR}` | `${VAR}` (same) |
| **Testing method** | curl | printf + pipe |
| **Use case** | Cloud APIs | Local commands |
| **Failure visibility** | HTTP errors visible | Process start errors |

**MCP servers don't crash the app** — They fail gracefully with a log message. Always check `systemctl status meow` or service logs when a tool seems unavailable.

## Trigger Conditions
- Adding a new MCP server to `.mcp.json`
- Agent can't access expected tools
- Testing new MCP server configuration
- Debugging "initialize failed" or "no server info" errors
