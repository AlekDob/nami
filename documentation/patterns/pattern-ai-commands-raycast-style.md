---
type: pattern
project: namios
date: 2026-02-16
tags: [ai-commands, hotkeys, macos, ios, share-extension]
---

# AI Commands — Raycast-Style Text Processing

## Problem
User lost Raycast Pro. Needed a system where selecting text + pressing a global shortcut triggers an AI command (translate, summarize, rewrite, etc.) with configurable output routing.

## Architecture

### Data Flow
```
Select text → Global hotkey (macOS) or Share Extension (iOS)
    ↓
Capture text (AX API / ⌘C simulation / share input)
    ↓
Compile prompt: command.prompt.replacing("{input}", with: text)
    ↓
POST /api/command (lightweight LLM call — no tools/memory/session)
    ↓
Route output: clipboard | floating panel | chat
```

### Components

| Component | File | Purpose |
|-----------|------|---------|
| **AICommand** | `Sources/Features/AICommands/AICommand.swift` | SwiftData model + 6 presets + SharedDefaults sync |
| **AICommandsViewModel** | `Sources/Features/AICommands/AICommandsViewModel.swift` | CRUD + hotkey refresh |
| **AICommandsListView** | `Sources/Features/AICommands/AICommandsListView.swift` | Top-level sidebar section (not inside Settings) |
| **AICommandEditView** | `Sources/Features/AICommands/AICommandEditView.swift` | Form: name, prompt, output mode, shortcut |
| **AICommandExecutor** | `Sources/Core/QuickInput/AICommandExecutor.swift` | Core engine: capture → API → route output |
| **ResultPanel** | `Sources/Core/QuickInput/ResultPanel.swift` | Floating HUD panel (always dark, shimmer loader) |
| **SharedAICommand** | `Sources/Core/Models/SharedAICommand.swift` | Lightweight Codable for Share Extension |
| **Backend endpoint** | `src/api/routes.ts` — `POST /api/command` | Lightweight LLM call with fast model |

### Text Capture Strategy (macOS)
3-tier, in order of preference:
1. **AXUIElement** (Accessibility API) — reads `kAXSelectedTextAttribute` directly. No clipboard modification, instant. Works in most native apps.
2. **Simulated ⌘C** — CGEvent keystroke + pasteboard polling (50ms intervals, 500ms max). Fallback for Electron apps.
3. **Empty** — both failed, show error panel.

### Replace Functionality
- Stores `sourceApp` (frontmost app at trigger time)
- On Replace: clipboard ← result → activate source app → 150ms delay → simulate ⌘V
- CGEvent virtualKey 9 = V, with `.maskCommand`

### Fast Model Selection
`pickFastDirectModel()` in `src/config/models.ts`:
1. Direct fast models (Kimi K2, MiniMax, GLM Flash via Z.AI)
2. OpenRouter fast (if available)
3. Any available model

### ResultPanel UI
- **NSPanel** with `.nonactivatingPanel` style
- Always dark (`.preferredColorScheme(.dark)`)
- **No auto-dismiss** — user closes manually (X, Esc)
- **No resignKey dismiss** — panel stays when losing focus
- **Shimmer loader** (3 skeleton bars) during processing
- **Badge "Copied"** (green, in header) for clipboard mode
- **Replace** + **Copy** buttons (Copy shows "Copied" checkmark for 1.5s)

## Preset Commands

| # | Name | Shortcut | Output |
|---|------|----------|--------|
| 1 | Translate to English | ⌘⇧U | clipboard |
| 2 | Translate to French | ⌘⇧F | clipboard |
| 3 | Translate to Italian | ⌘⇧I | clipboard |
| 4 | Summarize | ⌘⇧⌥S | panel |
| 5 | Rewrite Formal | ⌘⇧⌥R | clipboard |
| 6 | Fix Grammar | ⌘⇧⌥G | clipboard |

### Modifier Flag Values
- `⌘⇧` = `0x120000`
- `⌘⇧⌥` = `0x1A0000`

## Key Gotchas

1. **NSEvent.ModifierFlags raw values** — `.command` = `0x100000`, `.shift` = `0x020000`, `.option` = `0x080000`. Combined ⌘⇧ = `0x120000` (NOT `0x180100`).
2. **NSUserNotification deprecated** on macOS 11+ — must use floating panel or UNUserNotification for visual feedback.
3. **CGEvent ⌘C unreliable** in sandboxed apps — AX API is the primary capture method.
4. **ResultPanel resignKey** — must NOT auto-dismiss, or the panel vanishes when source app reclaims focus.
5. **Light mode** — panel uses `.white.opacity()` colors, must force dark color scheme.
6. **"Copied to clipboard" prefix** — never concatenate status text with AI result. Use a separate badge.

## macOS Services (Right-Click Menu) — Feb 2026

Added as a **parallel channel** to hotkeys. Services appear under **right-click > Services > Nami/** in ALL apps.

- macOS passes selected text directly via `NSPasteboard` — no AX API, no ⌘C hack
- Works in Electron, sandboxed apps, and anywhere hotkeys fail
- 6 preset services + 1 generic "Process with Nami..." (opens command picker)
- Declared in `project.yml` → `NSServices` (xcodegen regenerates Info.plist)
- Registered at bootstrap: `NSApp.servicesProvider = provider`
- Full details: `patterns/pattern-macos-services-right-click-integration.md`

### New Components
| Component | File | Purpose |
|-----------|------|---------|
| **NamiServicesProvider** | `Sources/Core/QuickInput/NamiServicesProvider.swift` | `@objc` service handlers |
| **ServicePickerPanel** | `Sources/Core/QuickInput/ServicePickerPanel.swift` | Floating HUD for generic picker |

## iOS (Share Extension)
- Picks from `SharedAICommand` synced via App Group UserDefaults
- Horizontal chip selector for commands
- Same `POST /api/command` endpoint
