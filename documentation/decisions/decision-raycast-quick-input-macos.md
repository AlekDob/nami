---
type: decision
title: Raycast-Style Quick Input for macOS
date: 2026-02-12
tags: [macos, quick-input, keyboard-shortcut, nsPanel, menu-bar]
status: implemented
---

# Decision: Raycast-Style Quick Input for macOS

## Context
NamiOS needed a way to quickly send messages to Nami without switching to the app. Similar to Raycast/Spotlight, a global keyboard shortcut should bring up a floating input bar.

## Decision
Implemented using pure Apple frameworks (no third-party deps):

### Architecture
- **GlobalHotkeyManager**: `NSEvent.addGlobalMonitorForEvents` + `addLocalMonitorForEvents` for system-wide hotkey detection
- **QuickInputPanel**: `NSPanel` subclass with `.nonactivatingPanel` + `.floating` level, `NSVisualEffectView` blur
- **QuickInputView**: SwiftUI view hosted in `NSHostingView` inside the panel
- **MenuBarExtra**: SwiftUI scene for persistent menu bar presence
- **HotkeyRecorderView**: Custom shortcut recorder for Settings

### Key Choices
1. **NSEvent over CGEventTap** — Simpler, read-only sufficient, no Input Monitoring permission needed
2. **NSPanel over NSWindow** — `.nonactivatingPanel` avoids stealing focus from other apps
3. **MenuBarExtra (SwiftUI)** — Native macOS 13+ API, cleaner than manual StatusItem
4. **NotificationCenter for IPC** — Decouples QuickInput from ChatViewModel (`.quickInputSend` notification)
5. **Recreate panel each time** — Avoids stale SwiftUI state in NSHostingView

### Default Shortcut
⌘⇧N (Cmd + Shift + N) — customizable via HotkeyRecorderView in Settings

### Files Created
- `Sources/Core/QuickInput/GlobalHotkeyManager.swift`
- `Sources/Core/QuickInput/QuickInputPanel.swift`
- `Sources/Core/QuickInput/QuickInputView.swift`
- `Sources/Core/QuickInput/HotkeyRecorderView.swift`

### Files Modified
- `Sources/MeowApp.swift` — MenuBarExtra scene, lifecycle, hotkey init
- `Sources/ContentView.swift` — Navigation observers for external triggers
- `Sources/Features/Chat/ChatViewModel.swift` — `sendQuickMessage()` + observer
- `Sources/Features/Settings/SettingsView.swift` — Quick Input section
- `Sources/Features/Settings/SettingsViewModel.swift` — Hotkey manager bridge
- `Sources/Info.plist` — NSAccessibilityUsageDescription

### Permissions
- **Accessibility** (AXIsProcessTrusted) — Required for global hotkey, prompted on first use
- No additional entitlements needed (sandbox-compatible)

## Gotchas
- `NSEvent.addGlobalMonitorForEvents` only works with Accessibility permission granted
- Panel must be recreated each time to avoid stale SwiftUI state
- `applicationShouldTerminateAfterLastWindowClosed` must return false for menu bar persistence
- Self-capture in closures within struct (App) needs care — uses NotificationCenter to decouple

## Trade-offs Considered
- **CGEventTap**: More powerful but requires Input Monitoring permission + system-wide privileges; avoided
- **LaunchAgent**: Could run as separate process; rejected for simplicity (single app)
- **Hardcoded shortcut**: Rejected to allow user customization

## Success Criteria
- Global hotkey triggers panel from any app
- Message sends without app activation
- Menu bar icon always visible
- Settings allow hotkey customization
- Zero third-party Swift dependencies
