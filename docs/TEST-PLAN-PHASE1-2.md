# Meow — Manual Test & Documentation Guide

> Covers Phase 1 (agent loop + tools + memory), Phase 2 (scheduler + email + X), Phase 3 (skills + Discord + flush), and Phase 4 (Soul System + Smart Model Selection).
> Updated after Phase 4 implementation. Total: 36 tests.

---

## How Meow Works

Meow is an always-on AI personal assistant running on a Hetzner server. It uses an
agentic loop: the user sends a message, the agent assembles context (system prompt +
memory), calls the model, which autonomously decides which tools to invoke
(up to 10 steps), then returns the final response.

### Architecture

```
                     CLI (interactive REPL)
                            |
                     +------v------+
                     |   Agent     |
                     |  .run()     |
                     +------+------+
                            |
            +---------------+---------------+
            |               |               |
    buildSystemPrompt   generateText    appendToDaily
    (base + MEMORY.md   (model + tools   (daily notes)
     + daily tail)       + stopWhen)
            |               |
     MemoryStore      +-----------+
     (2-layer +       | Tools     |
      SQLite index)   +-----------+
                      | webFetch  |
                      | fileRead  |
                      | fileWrite |
                      | memSearch |
                      | memGet    |
                      | emailRead |
                      | xTimeline |
                      | xSearch   |
                      | xMentions |
                      +-----------+

    Scheduler (cron.ts)
        |
        +-> triggers agent.run() on schedule
        +-> persists jobs to data/jobs/jobs.json
```

### Where Things Live

| File | What it does |
|------|-------------|
| `src/agent/agent.ts` | Agent class: model routing, tool wiring, run loop |
| `src/agent/system-prompt.ts` | Builds system prompt from base + memory context |
| `src/cli.ts` | Interactive REPL with cat animation, history, commands |
| `src/tools/index.ts` | Tool registry: coreTools + buildTools(memory) |
| `src/tools/web-fetch.ts` | Fetch URLs, return text content |
| `src/tools/file-read.ts` | Read files from data/ (sandboxed) |
| `src/tools/file-write.ts` | Write files to data/ (sandboxed) |
| `src/tools/memory-search.ts` | Hybrid search (vector + keyword) across memory |
| `src/tools/memory-get.ts` | Read specific lines from memory after search |
| `src/tools/email-read.ts` | IMAP email reader (imapflow) |
| `src/tools/x-api.ts` | Twitter API v2: timeline, search, mentions |
| `src/memory/store.ts` | 2-layer MemoryStore (MEMORY.md + daily notes) |
| `src/memory/types.ts` | MemoryConfig, SearchResult, Chunk interfaces |
| `src/memory/indexer.ts` | SQLite FTS5 + sqlite-vec indexer |
| `src/memory/embeddings.ts` | Optional OpenAI embedding provider |
| `src/scheduler/cron.ts` | Scheduler class: job CRUD + interval runner |
| `src/scheduler/types.ts` | Job, JobStore interfaces |
| `src/config/index.ts` | Config loader from env vars |
| `src/config/types.ts` | Config type interfaces |
| `src/utils/runtime.ts` | Bun/Node runtime detection |
| `src/agent/flush.ts` | Pre-compaction memory flush (estimateTokens, shouldFlush, runMemoryFlush) |
| `src/skills/types.ts` | Skill interfaces (SkillMeta, Skill) |
| `src/skills/loader.ts` | Skill loader: reads .md files with YAML frontmatter |
| `src/channels/discord.ts` | Discord bot: /ask, /status, /jobs, /memory slash commands |
| `src/cli/ui.ts` | CLI UI: colors, cat animation, tool animation, printing |
| `src/cli/commands.ts` | CLI commands: /exit, /clear, /model |
| `src/cli/index.ts` | CLI main loop, agent init, Discord auto-start |

### Data Directory

```
data/
├── memory/{userId}/
│   ├── MEMORY.md            # Layer 2: curated long-term knowledge
│   ├── daily/
│   │   └── YYYY-MM-DD.md   # Layer 1: append-only daily notes
│   └── index.sqlite         # Vector + FTS5 search index
├── jobs/
    └── jobs.json            # Scheduler job persistence
└── skills/
    └── *.md                 # Skill files with YAML frontmatter
```

### Memory System (Clawdbot-inspired)

Two layers:
- **Layer 1 (daily/)**: Append-only daily notes. Agent writes transient info here.
- **Layer 2 (MEMORY.md)**: Curated long-term knowledge. Agent writes durable facts here.

Search uses SQLite hybrid: `0.7 * vectorScore + 0.3 * keywordScore` (minScore 0.35).
No `memorySave` tool — agent writes to memory via standard `fileWrite`.

---

## Pre-requisites

1. SSH into the server:
   ```
   ssh root@ubuntu-4gb-hel1-1
   ```

2. Navigate to the project:
   ```
   cd /root/meow
   ```

3. Verify env vars are set:
   ```
   cat .env | grep -v '^#' | grep -v '^$'
   ```
   You need at least one API key (OPENROUTER_API_KEY or MOONSHOT_API_KEY).

4. Ensure Bun is in PATH:
   ```
   export PATH=$PATH:/root/.bun/bin
   ```

---

## Manual Testing

### Test 1: TypeScript Compilation

**What**: Entire codebase compiles without errors under strict mode.

```
bun run typecheck
```

- [ ] Command exits with code 0 (no output = success)

---

### Test 2: CLI Startup & Cat Animation

```
bun run dev
```

- [ ] ASCII cat animation plays (~1.5s)
- [ ] Header shows "Meow -- AI Personal Assistant"
- [ ] Runtime, model name, and commands displayed
- [ ] "Agent ready!" message and `>` prompt

---

### Test 3: Basic Conversation

```
> ciao, come ti chiami?
```

- [ ] Thinking animation: `(=^.^=) thinking...`
- [ ] Response mentions being "Meow"
- [ ] No errors

---

### Test 4: Conversation History

```
> il mio colore preferito e' il blu
> qual e' il mio colore preferito?
```

- [ ] Second response correctly references "blu"

---

### Test 5: Language Auto-Detection

```
> dimmi una curiosita' sui gatti
> tell me a fun fact about cats
```

- [ ] Italian input -> Italian response
- [ ] English input -> English response

---

### Test 6: Memory Write via fileWrite

**What**: Agent writes to MEMORY.md or daily notes when asked to remember.

```
> ricordati che il mio nome e' Alek e lavoro come Product Manager
```

Verify:
```
cat /root/meow/data/memory/default/MEMORY.md
ls /root/meow/data/memory/default/daily/
```

- [ ] Agent confirms it saved the information
- [ ] Info appears in MEMORY.md or today's daily note
- [ ] Agent used `fileWrite` tool (no dedicated memorySave)

**Note**: Durable facts go to MEMORY.md, transient notes to daily/YYYY-MM-DD.md.

---

### Test 7: Memory Recall After Restart

1. Exit with `/exit`
2. Restart: `bun run dev`
3. Ask: `come mi chiamo?`

- [ ] Agent recalls "Alek" from MEMORY.md loaded at startup

---

### Test 8: Memory Search (Hybrid)

```
> cerca nella tua memoria cosa sai di me
```

- [ ] Agent uses memorySearch tool
- [ ] Returns results with scores
- [ ] References previously saved info

---

### Test 9: Daily Session Logging

After any conversation:
```
cat /root/meow/data/memory/default/daily/$(date +%Y-%m-%d).md
```

- [ ] Daily file exists with today's date
- [ ] Contains conversation entries with timestamps

---

### Test 10: SQLite Index

```
ls -la /root/meow/data/memory/default/index.sqlite
```

- [ ] `index.sqlite` file exists
- [ ] File grows after memory writes

---

### Test 11: Web Fetch Tool

```
> fetch the content from https://httpbin.org/get and tell me what it returns
```

- [ ] Agent uses webFetch tool
- [ ] Response includes JSON from httpbin

---

### Test 12: File Write + Read Tools

```
> crea un file chiamato test-note.txt in data con scritto "Meow is alive!"
> leggi il contenuto del file data/test-note.txt
```

- [ ] File created, read back correctly, exists on disk

---

### Test 13: CLI Commands

```
/model          -> shows current model
/model openai/gpt-4o  -> switches model
/clear          -> resets screen
/exit           -> exits cleanly with "(=^.^=) Bye bye! Meow~"
```

- [ ] All commands work as expected

---

### Test 14: Scheduler Startup

Start Meow, then: `ls -la /root/meow/data/jobs/`

- [ ] No scheduler errors during startup
- [ ] `data/jobs/` directory created

---

### Test 15: Multi-step Tool Use

```
> fetch https://httpbin.org/uuid and save the result to data/uuid.txt
```

- [ ] Agent chains webFetch + fileWrite in one turn
- [ ] `data/uuid.txt` exists with UUID

---

### Test 16: Error Handling

```
> fetch the content from https://this-domain-does-not-exist-12345.com
```

- [ ] Graceful error message
- [ ] Meow continues running

---

### Test 17: Email Tool (requires IMAP config)

> Skip if IMAP not configured in `.env`

```
> check my email inbox, show me the last 3 messages
```

- [ ] With config: returns subjects, senders, dates
- [ ] Without config: reports "not configured" gracefully

---

### Test 18: X/Twitter Tool (requires bearer token)

> Skip if X_BEARER_TOKEN not configured

```
> search recent tweets about "artificial intelligence" on X
```

- [ ] With config: returns tweets with metrics
- [ ] Without config: reports "not configured" gracefully

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `bun: command not found` | `export PATH=$PATH:/root/.bun/bin` |
| API key not configured | Check `.env`, ensure PROVIDER matches key |
| 401 Unauthorized | Key invalid/expired, check provider dashboard |
| Agent doesn't use tools | Try `/model openai/gpt-4o` (more capable) |
| Memory files missing | Check `data/memory/default/`, `agent.init()` may have failed |
| SQLite index missing | Verify `bun:sqlite` + `sqlite-vec` available |

---

### Test 19: Skill Loading

**What**: Skill files from `data/skills/` are loaded and injected into system prompt.

```
ls /root/meow/data/skills/
bun run dev
> what skills do you have?
```

- [ ] `x-growth-advisor.md` exists in `data/skills/`
- [ ] Agent mentions X/Twitter growth advisor capabilities
- [ ] No startup errors about skills

---

### Test 20: Skill Frontmatter Parsing

**What**: YAML frontmatter is correctly parsed from skill files.

Check skill file format:
```
head -10 /root/meow/data/skills/x-growth-advisor.md
```

- [ ] Has `---` delimited frontmatter with name, description, tools
- [ ] Body text follows after closing `---`

---

### Test 21: Pre-compaction Memory Flush

**What**: When conversation context approaches 75% of context window (128k tokens), agent silently saves important info to memory before continuing.

> This is hard to test manually (requires ~96k tokens of conversation).
> Verify the code path exists:

```
grep -n "shouldFlush\|runMemoryFlush" /root/meow/src/agent/agent.ts
grep -n "estimateTokens\|shouldFlush\|runMemoryFlush" /root/meow/src/agent/flush.ts
```

- [ ] `shouldFlush()` called in agent.run() before generateText
- [ ] `runMemoryFlush()` triggers silent flush turn with fileWrite tools
- [ ] Threshold at 75% of 128k context window

---

### Test 22: Tool Use Animation

**What**: When agent calls a tool, an ASCII animation shows in CLI.

```
bun run dev
> fetch the content from https://httpbin.org/get
```

- [ ] Magenta-colored tool name appears (e.g., `🔧 Web Fetch`)
- [ ] Tool label is auto-generated from camelCase (webFetch → Web Fetch)
- [ ] Thinking animation resumes after tool display

---

### Test 23: Discord Bot Startup (requires DISCORD_TOKEN)

> Skip if Discord not configured in `.env`

```
# Ensure .env has DISCORD_TOKEN and DISCORD_CLIENT_ID
bun run dev
```

- [ ] "Discord bot connected!" message in magenta
- [ ] Bot appears online in Discord server
- [ ] Slash commands registered: /ask, /status, /jobs, /memory

---

### Test 24: Discord /ask Command

In Discord:
```
/ask message: ciao, come ti chiami?
```

- [ ] Bot shows "thinking..." (deferred reply)
- [ ] Response arrives within timeout
- [ ] Response mentions being Meow

---

### Test 25: Discord /status Command

```
/status
```

- [ ] Shows uptime (Xh Xm Xs)
- [ ] Shows memory usage (MB)
- [ ] Shows runtime info

---

### Test 26: Discord /memory Command

```
/memory query: Alek
```

- [ ] Shows search results with scores
- [ ] Results reference previously saved memory
- [ ] "No results" if memory is empty

---

### Test 27: CLI DRY Structure

**What**: CLI code is split into modular files under 300 lines each.

```
wc -l /root/meow/src/cli/ui.ts /root/meow/src/cli/commands.ts /root/meow/src/cli/index.ts
```

- [ ] `ui.ts` handles colors, animations, printing (~113 lines)
- [ ] `commands.ts` handles /exit, /clear, /model (~64 lines)
- [ ] `index.ts` handles main loop, agent init (~115 lines)
- [ ] All files under 300 lines

---

### Test 28: Smart Model Auto-Selection

**What**: System auto-selects best model based on available API keys and preset.

```
# Check .env has at least OPENROUTER_API_KEY
bun run dev
```

- [ ] Header shows model with preset info: e.g., `GPT-4o Mini [smart] (tools: ✓)`
- [ ] NOT showing raw model ID like `kimi-k2-0905-preview`
- [ ] Model with tool use support is preferred over models without

---

### Test 29: /models Command

```
> /models
```

- [ ] Lists available models grouped by tier (FAST, SMART, PRO)
- [ ] Shows `✓tools` or `✗tools` for each model
- [ ] Shows `← current` next to active model
- [ ] Only shows models for which API keys are configured

---

### Test 30: /model Switch Command

```
> /model
> /model gpt-4o
> /model kimi
```

- [ ] `/model` alone shows current model with preset and tool info
- [ ] `/model gpt-4o` switches and confirms: `Switched to GPT-4o (tools: ✓)`
- [ ] `/model kimi` warns: `(tools: ✗ — may not write to memory)`
- [ ] Partial name matching works (e.g., `gpt-4o` matches `openai/gpt-4o`)

---

### Test 31: Model Preset via ENV

```
# In .env, set:
MODEL_PRESET=pro
# Then restart
bun run dev
```

- [ ] With `pro`: selects GPT-4o or Claude 3.5 Sonnet (if key available)
- [ ] With `fast`: selects Gemini Flash (via OpenRouter) or Kimi K2
- [ ] With `smart` (default): selects GPT-4o Mini or Claude 3.5 Haiku
- [ ] Preset respects which API keys are actually configured

---

### Test 32: Tool Use Verification with Smart Model

**What**: With a tool-use capable model, fileWrite actually gets called.

```
# Ensure MODEL_PRESET=smart (GPT-4o Mini)
bun run dev
> ricordati che mi chiamo Alek e sono un Product Manager
```

- [ ] `~{=^w^=} writing` animation appears in magenta (tool was called)
- [ ] Agent confirms save
- [ ] Verify: `cat /root/meow/data/memory/default/MEMORY.md` contains "Alek"
- [ ] Compare: with Kimi K2, this animation did NOT appear (tool not called)

---

### Test 33: Soul System — First Run Onboarding

**Prerequisites**: No `data/soul/SOUL.md` exists
**Steps**:
1. Delete SOUL.md: `rm /root/meow/data/soul/SOUL.md`
2. Start: `bun run dev`
3. Observe startup message

**Expected**:
- [ ] CLI shows `✨ First time? Let's set up your cat!`
- [ ] Agent sends first message automatically (onboarding)
- [ ] Agent introduces itself as a newborn cat
- [ ] Agent asks for personality, name, quirks
- [ ] After answering, agent calls `fileWrite` to save `soul/SOUL.md`

**Verify**:
```bash
cat /root/meow/data/soul/SOUL.md
```
Should contain `# Soul`, `## Identity`, `## Traits`, `## Voice`, `## Backstory` with user's answers.

---

### Test 34: Soul System — Personality Persistence

**Prerequisites**: Test 33 passed (SOUL.md exists)
**Steps**:
1. Restart: `bun run dev`
2. Check that NO onboarding message appears
3. Chat normally — agent should embody the personality from SOUL.md

**Expected**:
- [ ] No `✨ First time?` message at startup
- [ ] Agent's tone matches the personality in SOUL.md
- [ ] Normal `Agent ready!` message shown

---

### Test 35: Soul System — Personality Change

**Prerequisites**: SOUL.md exists
**Steps**:
1. Tell the agent: "da ora sii più sarcastico e usa emoji di gatti"
2. Check if agent updates SOUL.md

**Expected**:
- [ ] `~{=^w^=} writing` animation appears (fileWrite called)
- [ ] SOUL.md updated with new personality traits
- [ ] Subsequent responses reflect the new personality

**Verify**:
```bash
cat /root/meow/data/soul/SOUL.md
```

---

### Test 36: MEMORY.md Overwrite Protection

**Prerequisites**: MEMORY.md exists with content
**Steps**:
1. Check current MEMORY.md content: `cat /root/meow/data/memory/default/MEMORY.md`
2. Tell the agent: "ricordati che il mio linguaggio preferito è TypeScript"
3. Check MEMORY.md again

**Expected**:
- [ ] `~{=^w^=} writing` animation appears
- [ ] New preference is added to MEMORY.md
- [ ] ALL previous sections are preserved (not overwritten)
- [ ] File still contains original profile info (name, role, etc.)

**Verify**:
```bash
cat /root/meow/data/memory/default/MEMORY.md
```
Should contain BOTH old content and new "TypeScript" preference.


### Test 37 — Schedule Reminder via Natural Language

**Goal**: Agent uses scheduleTask tool when asked to set a reminder
**Steps**:
1. Start Meow: bun run dev
2. Type: "ricordami tra 5 minuti di bere acqua"
3. Observe tool animation: should show scheduleTask being called

**Pass criteria**:
- [ ] Agent calls scheduleTask tool (magenta animation visible)
- [ ] Agent confirms reminder was set with time info
- [ ] Check: cat data/jobs/jobs.json — should contain the job

### Test 38 — Reminder Notification Fires

**Goal**: Verify CLI shows notification when reminder triggers
**Steps**:
1. Start Meow: bun run dev
2. Type: "ricordami tra 1 minuto di testare"
3. Wait 1+ minutes

**Pass criteria**:
- [ ] Yellow "=^.^= REMINDER" message appears in CLI
- [ ] Reminder message displayed correctly
- [ ] Prompt re-appears after notification

### Test 39 — List Reminders

**Goal**: Agent can list active reminders
**Steps**:
1. Set a reminder first (Test 37)
2. Type: "quali reminder ho attivi?"

**Pass criteria**:
- [ ] Agent calls listTasks tool
- [ ] Shows job ID, name, cron, enabled status

### Test 40 — Cancel Reminder

**Goal**: Agent can cancel a reminder by ID
**Steps**:
1. Set a reminder, note the job ID from listTasks
2. Type: "cancella il reminder [ID]"

**Pass criteria**:
- [ ] Agent calls cancelTask tool with correct ID
- [ ] Confirms cancellation
- [ ] listTasks no longer shows that job

### Test 41 — Recurring Reminder

**Goal**: Recurring reminders fire repeatedly
**Steps**:
1. Type: "ogni giorno alle 9 ricordami di fare standup"
2. Check: cat data/jobs/jobs.json

**Pass criteria**:
- [ ] Job has repeat: true
- [ ] Cron is "0 9 * * *"


### Test 42 — Scheduled Autonomous Action (webFetch)

**Goal**: Agent schedules a task that uses tools (not just a notification)
**Steps**:
1. Start Meow: bun run dev
2. Type: tra 2 minuti vai su ansa.it e dammi un riepilogo delle notizie
3. Wait 2+ minutes

**Pass criteria**:
- [ ] Agent calls scheduleTask tool with task describing the web fetch action
- [ ] After 2 minutes, CLI shows =^.^= SCHEDULED TASK: ... header in yellow
- [ ] Agent output contains actual news from ansa.it (webFetch was used)
- [ ] Prompt re-appears after output
