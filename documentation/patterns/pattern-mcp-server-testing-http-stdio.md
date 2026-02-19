---
type: pattern
project: namios
created: 2026-02-12
tags: [mcp, testing, debugging, http, stdio, json-rpc, validation]
---

# Pattern: MCP Server Testing (HTTP vs Stdio)

## Overview
Reliable pattern for testing MCP servers **before integrating into `.mcp.json`**. Both HTTP and stdio servers speak JSON-RPC 2.0 protocol, so validation is similar — only the invocation method differs.

## HTTP Server Testing Pattern

### 1. Prepare the Initialize Request

```bash
# Store the JSON-RPC request
REQUEST='{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2024-11-05",
    "capabilities": {},
    "clientInfo": {
      "name": "namios-mcp-client",
      "version": "1.0.0"
    }
  }
}'
```

### 2. Test with curl

```bash
curl -X POST "https://mcp.example.com/mcp" \
  -H "Authorization: Bearer ${API_KEY}" \
  -H "Accept: application/json, text/event-stream" \
  -H "Content-Type: application/json" \
  -d "$REQUEST"
```

### 3. Validate Response

Expected success response:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "result": {
    "protocolVersion": "2024-11-05",
    "capabilities": {
      "tools": [...],
      "resources": [...]
    },
    "serverInfo": {
      "name": "server-name",
      "version": "1.0.0"
    }
  }
}
```

If you see an error:
```json
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32600,
    "message": "Invalid Request",
    "data": {...}
  }
}
```

Check:
- [ ] API key is valid (not expired, not revoked)
- [ ] Endpoint URL is correct
- [ ] Authorization header format (Bearer token, not Basic auth)
- [ ] Firewall/CORS allows your request

## Stdio Server Testing Pattern

### 1. Prepare the Initialize Request

```bash
# Same JSON-RPC request as HTTP
REQUEST='{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2024-11-05",
    "capabilities": {},
    "clientInfo": {
      "name": "namios-mcp-client",
      "version": "1.0.0"
    }
  }
}'
```

### 2. Test with Printf + Pipe

```bash
# For Mixpanel with --token
printf '%s\n' "$REQUEST" | npx -y mixpanel-mcp-server --token d216030c...

# For custom command with env
printf '%s\n' "$REQUEST" | CUSTOM_VAR=value custom-tool arg1 arg2

# For local Python tool
printf '%s\n' "$REQUEST" | python /path/to/tool.py --config config.json
```

### 3. Validate Response

Expected success:
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

Common failures:

**Command not found:**
```
sh: npx: command not found
```
→ Check PATH, ensure npx/bun/python is installed

**Token rejected:**
```
{
  "jsonrpc": "2.0",
  "id": 1,
  "error": {
    "code": -32603,
    "message": "Invalid token"
  }
}
```
→ Verify token is correct, not expired, has necessary scopes

**Wrong argument format:**
```
Error: Unknown option --token
```
→ Check server's CLI help: `npx -y mixpanel-mcp-server --help`

## Full Testing Workflow

### Step 1: Identify Transport Type
```bash
# HTTP: Cloud-based
# Example: PostHog at https://mcp-eu.posthog.com/mcp

# Stdio: Local command
# Example: mixpanel-mcp-server (npm package)
```

### Step 2: Test Transport
```bash
# HTTP
curl -X POST "..." -H "Authorization: Bearer ${KEY}" -d "$REQUEST"

# Stdio
printf '%s\n' "$REQUEST" | command --token-arg value
```

### Step 3: Validate Protocol
Check response contains:
- [ ] `"jsonrpc": "2.0"` (protocol version)
- [ ] `"id": 1` (request ID echo)
- [ ] `"result"` with `"serverInfo"` (success) OR `"error"` (failure)
- [ ] `"protocolVersion": "2024-11-05"` (MCP version)

### Step 4: Integrate to `.mcp.json`
Once curl/printf test succeeds:

```json
{
  "posthog": {
    "type": "http",
    "url": "https://mcp-eu.posthog.com/mcp",
    "headers": {
      "Authorization": "Bearer ${POSTHOG_API_KEY}"
    }
  },
  "mixpanel": {
    "type": "command",
    "command": "npx",
    "args": ["-y", "mixpanel-mcp-server", "--token", "${MIXPANEL_TOKEN}"]
  }
}
```

### Step 5: Verify Service
```bash
# Restart service with new config
systemctl restart meow

# Check logs for [MCP] messages
systemctl status meow
# Should see: [MCP] posthog connected
#           [MCP] mixpanel connected
```

## Real-World Examples

### PostHog HTTP Test
```bash
curl -X POST "https://mcp-eu.posthog.com/mcp" \
  -H "Authorization: Bearer phx_TFOOSlHUFGycynXEe5L3JTjZlkA8..." \
  -H "Accept: application/json, text/event-stream" \
  -d '{
    "jsonrpc": "2.0",
    "id": 1,
    "method": "initialize",
    "params": {
      "protocolVersion": "2024-11-05",
      "capabilities": {},
      "clientInfo": {"name": "namios", "version": "1.0.0"}
    }
  }'

# Expected: Server info with tools: ["insights", "dashboards", "events", "resources"]
```

### Mixpanel Stdio Test
```bash
printf '{
  "jsonrpc": "2.0",
  "id": 1,
  "method": "initialize",
  "params": {
    "protocolVersion": "2024-11-05",
    "capabilities": {},
    "clientInfo": {"name": "namios", "version": "1.0.0"}
  }
}\n' | npx -y mixpanel-mcp-server --token d216030c...

# Expected: Server info with tools: ["track", "track_pageview", "signup"]
```

## Key Insights

1. **JSON-RPC 2.0 is the universal protocol** — Same request/response format for both HTTP and stdio
2. **Test before integrating** — printf/curl catches configuration errors early
3. **Token delivery varies** — Check server's docs for CLI arg vs env var vs header
4. **Silent failures are normal** — MCP servers don't crash the app, just log errors
5. **Protocol is simple** — Initialize request returns server capabilities, that's it

## Trigger Conditions
- Onboarding a new MCP server
- Debugging "MCP server not connecting" issues
- Verifying credentials before committing to `.mcp.json`
- Testing custom/local MCP tools
