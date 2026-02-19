---
type: pattern
title: Self-Managing Skills - Agent creates its own capabilities
tags: [skills, vercel-ai-sdk, self-improvement, agent-loop, markdown]
date: 2026-02-02
status: verified
---

# Self-Managing Skills

Allow the AI agent to create, list, and delete its own skill files during runtime. Skills are `.md` files with YAML frontmatter loaded into the system prompt for every `generateText()` call.

## Architecture

```
Agent Loop (generateText + tools)
    |
    +-- createSkill(name, description, body, tools?, schedule?)
    +-- listSkills() → ["skill-1", "skill-2", ...]
    +-- deleteSkill(name)
    |
    v
data/skills/  ← .md files with YAML frontmatter
    |
    v
SkillLoader → inject into system prompt
```

## Skill File Format

```markdown
---
name: bookmark-saver
description: Save bookmarks shared by the user to memory
tools: [memoryWrite, memorySearch]
schedule: null
---

# Bookmark Saver

When the user shares a URL or says "save this":
1. Extract URL + title
2. Use memoryWrite to save under "Bookmarks" section
3. Confirm with the user
```

## Why This Pattern?

- **Self-improving agent** — recognizes gaps in capabilities and creates skills to fill them
- **No code deployment** — skills are markdown files, hot-reloaded every run
- **Auditable** — all skills are plain text `.md` files
- **Composable** — skills can reference other tools (`tools: [memoryWrite, webFetch]`)

## Gotchas

1. **Name conflicts** — `createSkill` overwrites if file exists
2. **No validation** — loader blindly injects all `.md` files. Sanitize if multi-user
3. **Token bloat** — too many skills → context overflow. Implement pruning
4. **No hot reload mid-conversation** — skills load once per `generateText()` call
5. **Schedule field** — parsed but not implemented (needs cron job integration)

## Related

- `patterns/pattern-env-hot-reload-without-restart.md` — Env var hot reload pattern
- Scheduler (`src/scheduler/`) — could trigger scheduled skills
