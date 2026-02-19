---
type: decision
title: Tailscale + Local Agent over SSH Reverse Tunnel
date: 2026-02-14
tags: [tailscale, ssh, architecture, security]
status: accepted
---

# Decision: Tailscale + Local Agent over SSH Reverse Tunnel

## Context
Nami (server in Helsinki) needs to access Alek's Mac for file reading and command execution. The Mac is behind NAT with no public IP.

## Options Evaluated

| Option | Setup | Security | Reliability | Maintenance |
|--------|-------|----------|-------------|-------------|
| SSH Reverse Tunnel | Medium | Risky (open shell) | Fragile (drops) | autossh/launchd |
| **Tailscale + Agent** | **Low** | **Excellent (WireGuard)** | **Excellent** | **Near zero** |
| Upload Endpoint | Low | Good | Good | Low |
| Full SSH Access | Low | Maximum risk | Good | Low |

## Decision
**Tailscale + Local Node.js Agent**

Tailscale was already installed on all 3 devices (Mac, Server, iPhone). The agent provides a controlled HTTP API with bearer auth, command whitelist, and path sanitization. ~130ms latency Helsinki → Mac.

## Consequences
- Mac must be awake for Nami to access it
- Agent auto-starts via launchd, auto-restarts on crash
- Command whitelist must be manually expanded when needed
- If Hetzner server is compromised, attacker could access Mac files under /Users/alekdob (mitigated by bearer token)

## Alternatives Rejected
- **SSH Reverse Tunnel**: Fragile, tunnel drops silently, open shell = large attack surface
- **Upload Endpoint**: Doesn't cover command execution, worse UX
- **Full SSH**: Maximum risk, no command whitelist
