---
type: decision
project: namios
created: 2026-03-10
last_verified: 2026-03-10
tags: [api, integration, quack, skill, remote-access]
---

# Decision: Nami Remote API Skill

## Context

NamiOS has ~30 REST endpoints + WebSocket on the Hetzner server, but no way for external tools (Quack agents, other Claude Code projects) to discover and interact with these APIs without reading the source code.

## Decision

Created a global skill `nami-remote` (`~/.claude/skills/nami-remote/SKILL.md`) that documents the entire Nami API — similar to how `quack-remote` works for Quack's local API.

Also added the missing `POST /api/knowledge` endpoint to enable creating brain entries remotely (the internal `saveKnowledge()` method existed but wasn't exposed via REST).

## Connection Methods

Three documented approaches, in order of reliability:
1. **SSH proxy** (recommended) — `ssh root@ubuntu-4gb-hel1-1 'curl ... http://localhost:3000/...'` — works immediately, no firewall config
2. **Tailscale direct** — `http://100.81.200.26:3000` — requires port 3000 open on server firewall for Tailscale interface
3. **SSH tunnel** — `ssh -L 3000:localhost:3000 root@ubuntu-4gb-hel1-1 -N` — persistent local access

## Consequences

- Any Quack agent can now `@skill:nami-remote` and interact with Nami's brain, jobs, memory, chat
- Cross-project knowledge sharing: discoveries in one project can be saved to Nami's brain from another
- Job creation from external tools: Quack can schedule Nami tasks remotely
- The skill is global (`~/.claude/skills/`) so it works from any project
