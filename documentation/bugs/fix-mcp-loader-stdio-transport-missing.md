---
type: bug_fix
project: namios
created: 2026-02-12
tags: [mcp, stdio, transport, loader, integration]
---

# Fix: MCP Loader Limited to HTTP Transport Only

## Problem
The MCP loader (`src/mcp/loader.ts`) only supported `StreamableHTTPClientTransport`, which meant command-based MCP servers (that use stdio/stdin protocol) like Mixpanel couldn't connect. The interface was hardcoded to `type: 'http'` only.

**Impact**: Any stdio-based MCP server would silently fail with no connection, breaking agent capabilities for those tools.

## Root Cause
```typescript
// BEFORE: Only HTTP transport supported
interface HttpServerConfig {
  type: 'http';
  url: string;
  headers?: Record<string, string>;
}

// loader.ts only handled HTTP
const client = new Client(
  {
    name: 'http-server',
    version: '1.0.0',
  },
  {
    transport: new StreamableHTTPClientTransport({...})
  }
);
```

The `connectServer()` function checked `config.type === 'http'` but had no handling for command-based transports.

## Solution
Extended the configuration to support both HTTP and command-based servers with a union type:

```typescript
interface HttpServerConfig {
  type: 'http';
  url: string;
  headers?: Record<string, string>;
}

interface CommandServerConfig {
  type: 'command';
  command: string;
  args: string[];
  env?: Record<string, string>;
}

type McpServerConfig = HttpServerConfig | CommandServerConfig;
```

Added `StdioClientTransport` import and created `connectCommandServer()` function:

```typescript
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';

async function connectCommandServer(config: CommandServerConfig) {
  const transport = new StdioClientTransport({
    command: config.command,
    args: config.args,
    env: config.env,
  });

  return new Client(
    {
      name: config.command,
      version: '1.0.0',
    },
    { transport }
  );
}
```

Updated the main `connectServer()` to dispatch:

```typescript
if (config.type === 'http') {
  return connectHttpServer(config);
} else if (config.type === 'command') {
  return connectCommandServer(config);
}
```

## Verification
Tested Mixpanel MCP server connection:
```bash
printf '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05",...}}' | npx -y mixpanel-mcp-server --token <TOKEN>
```

Server responded with valid initialize response, confirming stdio protocol works.

## Files Modified
- `/root/meow/src/mcp/loader.ts` — Added `CommandServerConfig`, `StdioClientTransport`, and dispatch logic

## Key Insight
MCP supports two transport types:
- **HTTP**: For cloud-based MCP servers (PostHog, Claude's model context protocol servers)
- **Stdio**: For local command-based servers (Mixpanel, custom tools)

The loader must support both to be a complete MCP orchestrator.

## Trigger Conditions
- Adding a new stdio-based MCP server to `.mcp.json`
- Debugging "MCP server not connecting" with command-based tools
- Integrating local MCP tools that use stdin/stdout protocol
