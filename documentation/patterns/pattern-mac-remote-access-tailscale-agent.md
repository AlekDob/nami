---
type: pattern
project: namios
date: 2026-02-14
tags: [tailscale, mac-agent, remote-access, tools, node]
---

# Mac Remote Access via Tailscale + Local Agent

## Problem
Nami (server in Helsinki) cannot access Alek's Mac filesystem or execute local commands. The Mac is behind NAT with no public IP. Users want to say "read this file on my Mac" or "open Safari" and have Nami do it.

## Pattern: Tailscale VPN + Local HTTP Agent

### Architecture
```
Hetzner Server (Nami)  ──── Tailscale VPN ────▶  Mac Agent (Node.js)
100.81.200.26                                     100.89.38.120:7777
```

### Mac Agent (Node.js, zero deps)
Location: `/Users/alekdob/nami-agent/server.js`

Three endpoints:
| Endpoint | Method | Auth | Purpose |
|----------|--------|------|---------|
| `/health` | GET | No | Hostname + uptime |
| `/file?path=...` | GET | Bearer | Read file (text/binary, max 10MB) |
| `/exec` | POST | Bearer | Execute whitelisted command |

### Security Layers
1. **Tailscale**: WireGuard encrypted, not on public internet
2. **Bearer token**: constant-time comparison, shared secret in `.env`
3. **Path sanitization**: only `/Users/alekdob/` accessible
4. **Command whitelist**: `open`, `ls`, `cat`, `pbcopy`, `pbpaste`, `say`, `osascript`, `defaults read`, `sw_vers`, `df`, `uptime`, `whoami`, `date`, `screencapture`, `pmset`
5. **30s timeout** on command execution
6. **10MB limit** on file reads

### Nami Tools (Server-Side)
File: `src/tools/mac-remote.ts`

Two Vercel AI SDK tools registered conditionally in `src/tools/index.ts`:
- `macFileRead` — reads file from Mac, returns text or base64 for binary
- `macExec` — executes whitelisted command, returns stdout/stderr

Conditional: only registered if `MAC_AGENT_URL` + `MAC_AGENT_TOKEN` env vars are set.

### Tailscale Network
| Device | IP | OS |
|--------|-----|-----|
| Server (Hetzner) | 100.81.200.26 | Linux |
| Mac (HQ-ALEDOB) | 100.89.38.120 | macOS |
| iPhone | 100.126.173.127 | iOS |

### Auto-Start
launchd plist: `~/Library/LaunchAgents/com.nami.mac-agent.plist`
- `RunAtLoad: true`, `KeepAlive: true`
- Logs: `/Users/alekdob/nami-agent/agent.log`

## Key Files
| File | Location | Purpose |
|------|----------|---------|
| `server.js` | `/Users/alekdob/nami-agent/` | Mac Agent daemon |
| `.env` | `/Users/alekdob/nami-agent/` | Token + port config |
| `mac-remote.ts` | `src/tools/` | Nami tools (server) |
| `index.ts` | `src/tools/` | Tool registration |
| `com.nami.mac-agent.plist` | `~/Library/LaunchAgents/` | launchd auto-start |

## Managing the Agent
```bash
# Check status
curl http://localhost:7777/health

# View logs
tail -f ~/nami-agent/agent.log

# Restart
launchctl unload ~/Library/LaunchAgents/com.nami.mac-agent.plist
launchctl load ~/Library/LaunchAgents/com.nami.mac-agent.plist

# Add new commands: edit ALLOWED_COMMANDS in server.js
```

## Failure Modes
- Mac asleep/off → tools return "Mac is offline or unreachable"
- Token mismatch → 401 Unauthorized
- Command not whitelisted → 403 with allowed list
- File outside /Users/alekdob → 403 Path not allowed

## Related
- Decision: `decisions/decision-tailscale-over-ssh-tunnel.md`
