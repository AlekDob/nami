---
type: gotcha
project: namios
created: 2026-03-03
last_verified: 2026-03-03
tags: [vision, auto-routing, models, gemini, tools]
---

# Auto-Vision Routing Must Prefer Models with Tool Use

## Trigger
When auto-routing to a vision model for image messages, the selected model silently fails if it lacks `toolUse: true`.

## Problem
`pickVisionModel()` initially picked the first direct vision model in the registry — GLM-4.5V (`toolUse: false`). The agent uses tools (memory, scheduler, etc.), so when routed to a no-tools model:
- First request hangs (no response, no loader)
- Subsequent requests hit "database is locked" (SQLite still locked by hung request)

## Fix
`pickVisionModel()` filters in priority order:
1. Direct providers with `vision: true` AND `toolUse: true` (e.g. Gemini 2.5 Flash, GPT-4o Mini)
2. Any direct vision model (fallback)
3. OpenRouter vision models (last resort)

## Also Fixed
- Vision-blocking guards in `websocket.ts`, `routes.ts`, `cli/index.ts` were removed — they rejected images BEFORE reaching the agent, making auto-routing impossible
- Old guards returned `HTTP 0` / WebSocket error to the client with "Current model does not support images"

## Key Insight
Any auto-routing function must match the capabilities the caller expects. The agent expects tools → the vision model must support tools. Silent capability mismatch = silent failure.
