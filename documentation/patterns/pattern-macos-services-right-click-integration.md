---
type: pattern
project: namios
created: 2026-02-18
last_verified: 2026-02-18
tags: [macos, services, context-menu, right-click, ai-commands, nsservices]
---

# macOS Services — Right-Click AI Commands Integration

## Problem
AI Commands via global hotkeys have two issues:
1. **Shortcut conflicts** — `⌘⇧F`, `⌘⇧I` etc. clash with Xcode, browsers, and other apps
2. **Text capture fails in some apps** — AXUIElement doesn't work in Electron/Qt apps, simulated `⌘C` fails in sandboxed apps

## Solution
Register AI Commands as **macOS Services** via `NSApp.servicesProvider`. Services appear in the right-click context menu under **Services > Nami/** in ALL apps. macOS passes selected text directly — no AX API, no `⌘C` simulation.

## Architecture

```
User selects text → Right-click → Services → Nami/Translate to English
    ↓
macOS passes text via NSPasteboard (DIRECT — no capture hack)
    ↓
NamiServicesProvider.translateToEnglish() called by macOS
    ↓
AICommandExecutor.executeCommand(command, withInput: text)
    ↓
POST /api/command → ResultPanel (same as hotkey path)
```

## Components

| Component | File | Purpose |
|-----------|------|---------|
| **NamiServicesProvider** | `Sources/Core/QuickInput/NamiServicesProvider.swift` | `@objc` class with handler per service |
| **ServicePickerPanel** | `Sources/Core/QuickInput/ServicePickerPanel.swift` | Floating HUD picker for "Process with Nami..." |
| **Info.plist / project.yml** | `NSServices` array | Declares available services to macOS |

## Implementation

### 1. Services Provider (`@objc` required)

```swift
@objc final class NamiServicesProvider: NSObject {
    @objc func translateToEnglish(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        guard let text = pboard.string(forType: .string) else { return }
        Task { @MainActor in
            await executor?.executeCommand(command, withInput: text)
        }
    }
}
```

### 2. Info.plist Declaration (via project.yml)

Each service needs: `NSMessage` (selector name), `NSMenuItem.default` (menu label), `NSSendTypes` + `NSReturnTypes` (data types), `NSPortName` (app name).

### 3. Bootstrap Registration

```swift
NSApp.servicesProvider = provider
NSUpdateDynamicServices()
```

## Key Design Decisions

1. **Parallel to hotkeys** — Services don't replace global hotkeys. Both work simultaneously.
2. **Static presets + generic picker** — The 6 preset commands are individual services. A 7th "Process with Nami..." opens a picker for ALL commands (including user-created ones).
3. **NSServices are static** — Declared in Info.plist, can't be added at runtime. Custom commands use the generic picker.
4. **Reuses AICommandExecutor** — The `executeCommand(_, withInput:)` method is shared between hotkey and service paths.

## Advantages over Hotkeys

| Aspect | Hotkeys | Services |
|--------|---------|----------|
| Shortcut conflicts | Frequent | Zero |
| App compatibility | ~70% | ~99% |
| Text capture | AX API + ⌘C hack | macOS passes directly |
| Text replace | Simulated ⌘V | macOS does natively |
| Extra permissions | Accessibility | None |

## Gotcha: Services Not Showing

Three things must ALL be true for Services to appear in right-click menu:

1. **App must be in `/Applications`** — macOS PBS only discovers services from registered locations, NOT from Xcode DerivedData. See `gotchas/gotcha-macos-pbs-services-discovery-location.md`.
2. **`NSPortName` must match `CFBundleName`** (not display name!) — e.g. `NamiOS`, not `Nami`. See `gotchas/gotcha-nsportname-must-match-cfbundlename.md`.
3. **User must manually enable checkboxes** — System Settings → Keyboard → Keyboard Shortcuts → Services. macOS does NOT auto-enable new services (security restriction, cannot be bypassed programmatically).

Once enabled, services persist across app updates. Users can also assign custom keyboard shortcuts from this panel — Apple's native shortcut system with zero conflict risk.

## ServicePickerPanel Positioning

The "Process with Nami..." generic picker uses `NSEvent.mouseLocation` to open near the cursor (not centered). This gives contextual feel — the picker appears where the user right-clicked.
