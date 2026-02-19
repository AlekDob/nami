---
type: pattern
project: namios
created: 2026-02-18
last_verified: 2026-02-18
tags: [ai-commands, local-commands, bash, self-generation, tools]
---

# Local Commands + Self-Generation via Chat

## Problem
AI Commands always hit the server API, adding latency for simple text transformations (word count, uppercase, JSON pretty-print). Users also want Nami to create new commands autonomously when asked in chat.

## Solution
Two extensions to the AI Commands system:

### 1. Local Commands (bash execution)
Commands with `commandType == .local` run a bash script locally on the Mac instead of calling the AI API. Instant execution, no network needed.

### 2. Self-Generation
Nami has `createLocalCommand` and `createAICommand` tools. When a user asks "create a command that counts words", Nami calls the tool, the server stores it, and the client syncs on next load.

## Architecture

```
User: "crea un comando che conta le parole"
    |
    v
Nami agent → createLocalCommand tool
    |
    v
Server stores in data/commands.json
    |
    v
Client: syncFromServer() on AICommandsListView.onAppear
    |
    v
SwiftData: new AICommand(commandType: .local, script: "echo $NAMI_INPUT | wc -w | xargs")
    |
    v
User triggers via hotkey/Services → executeLocalScript() → Process("/bin/bash") → result
```

## Key Files

| Component | File | Purpose |
|-----------|------|---------|
| **AICommand model** | `Sources/Features/AICommands/AICommand.swift` | `commandTypeRaw`, `script` fields |
| **AICommandExecutor** | `Sources/Core/QuickInput/AICommandExecutor.swift` | `executeLocalScript()` with 10s timeout |
| **AICommandEditView** | `Sources/Features/AICommands/AICommandEditView.swift` | Type picker (AI/Local) + script field |
| **AICommandsViewModel** | `Sources/Features/AICommands/AICommandsViewModel.swift` | `syncFromServer()` for chat-created commands |
| **Server tools** | `src/tools/local-command.ts` | `createLocalCommand` + `createAICommand` |
| **REST endpoints** | `src/api/routes.ts` | `GET/POST/DELETE /api/commands` |

## Local Script Execution

```swift
// In AICommandExecutor
let process = Process()
process.executableURL = URL(fileURLWithPath: "/bin/bash")
process.arguments = ["-c", script]
env["NAMI_INPUT"] = input  // Selected text available as $NAMI_INPUT
// 10-second timeout via DispatchSource timer
```

## Example Commands

| Name | Script | Output |
|------|--------|--------|
| Word Count | `echo "$NAMI_INPUT" \| wc -w \| xargs` | panel |
| To Uppercase | `echo "$NAMI_INPUT" \| tr '[:lower:]' '[:upper:]'` | clipboard |
| JSON Pretty | `echo "$NAMI_INPUT" \| python3 -m json.tool` | panel |
| URL Encode | `python3 -c "import urllib.parse; print(urllib.parse.quote('''$NAMI_INPUT'''))"` | clipboard |

## Security Notes
- 10-second timeout prevents runaway scripts
- Scripts run as the current user (same as the app)
- Commands created via chat require the user to see them in the AI Commands list before use
