---
type: pattern
project: namios
created: 2026-02-18
last_verified: 2026-02-18
tags: [macos, notch, dynamic-island, nswindow, swiftui]
---

# Notch Panel — Dynamic Island-Style UI on macOS

A macOS notch overlay that mimics the iPhone Dynamic Island, providing always-available quick commands anchored to the built-in display notch.

## DynamicNotchKit Pattern

The panel is a large transparent `NSPanel` sized to `screen.width/2 x screen.height/2`, positioned at the top-center of the built-in display. Key window properties:

- **Level**: `.screenSaver` (above all windows including fullscreen apps)
- **Style**: `.borderless`, `.nonactivatingPanel` (does not steal focus from the current app)
- **Background**: fully transparent (`backgroundColor = .clear`, `isOpaque = false`)
- **Ignores mouse events** outside the visible notch shape (passthrough to apps below)

The visible UI is a small SwiftUI view clipped to a custom notch shape, floating inside the large transparent panel.

## NotchShape — Custom SwiftUI Shape

`NotchShape` is a custom `Shape` with animatable corner radii that draws a U-shaped cutout matching the macOS notch. The shape uses `addArc` and `addLine` calls to create smooth rounded corners. Corner radii animate between collapsed (tight, matching physical notch) and expanded (larger, pill-like) states using `Animatable` conformance on the shape data.

## NSScreen+Notch — Detecting the Physical Notch

An extension on `NSScreen` detects whether a display has a notch:

- **Primary method**: `auxiliaryTopLeftArea` (macOS 12+) — non-nil means a notch exists
- **Fallback**: `safeAreaInsets.top > 0` (macOS 12+)
- **Static property**: `NSScreen.screenWithNotch` returns the first screen with a notch (always the built-in display on MacBooks)

**Multi-monitor rule**: Always use `NSScreen.screenWithNotch` to find the built-in display. Do NOT use `NSScreen.main` — that follows keyboard focus and may be an external monitor without a notch.

## State Machine

The panel has three states managed by a `NotchStatus` enum:

| State | Width | Content | Trigger |
|-------|-------|---------|---------|
| **Collapsed** | ~200px | Compact "shoulders" flanking the physical notch | Default, mouse exit |
| **Expanded** | ~500px | Dark rounded panel with quick commands list | Hover or click on collapsed area |
| **Voice** | ~500px | Waveform + voice input UI | Hold-to-talk gesture |

Transitions use SwiftUI `.animation(.spring(...))` on the shape and content simultaneously.

## Content-Mask Alignment

The visible content is clipped to the `NotchShape` mask. A critical requirement: the content `.frame(width: maskWidth)` must exactly match the mask dimensions. If the content frame is wider than the mask, content overflows invisibly (clipped but still hit-testable). If narrower, content appears offset from the mask edges.

Both the mask and content width are driven by the same state-derived value to stay in sync.

## Anti-Cascade Communication

The notch panel communicates state changes via `NotificationCenter` posting a `NotchStatus` struct, rather than passing `@Observable` objects between the panel and the main app. This prevents the `@Observable` cascade problem (documented in `gotchas/gotcha-observable-cascade-rerender.md`) where SwiftUI subscribes to all properties of a passed-in observable, causing unnecessary re-renders across unrelated views.

## Quick Commands — AICommandExecutor Integration

Quick commands displayed in the expanded notch are wired to execute AI Commands (not chat messages) via a callback chain:

1. **NotchContentView** — user taps a command, calls `onExecuteCommand(command, selectedText)`
2. **NotchPanelManager** — holds the `onExecuteCommand` closure, set during initialization
3. **MeowApp** — wires the closure at app startup, bridging to `AICommandExecutor`
4. **AICommandExecutor** — captures selected text (via AXUIElement or clipboard), sends to `/api/command` endpoint, displays result in `ResultPanel` with Copy/Replace actions

This callback chain avoids passing the entire `AICommandExecutor` (an `@Observable`) into the notch view hierarchy.

## Key Files

| File | Purpose |
|------|---------|
| `Sources/Core/Notch/NotchPanelManager.swift` | NSPanel lifecycle, positioning, show/hide |
| `Sources/Core/Notch/NotchContentView.swift` | SwiftUI content (collapsed shoulders, expanded commands) |
| `Sources/Core/Notch/NotchShape.swift` | Custom animatable U-shape |
| `Sources/Core/Notch/NotchStatus.swift` | State enum + NotificationCenter bridge |
| `Sources/Core/Notch/NSScreen+Notch.swift` | Notch detection extension |
| `Sources/Core/Notch/NotchViewModel.swift` | State management, hover/click handling |
| `Sources/MeowApp.swift` | Wires onExecuteCommand callback |
| `Sources/Features/Chat/ChatViewModel.swift` | AICommandExecutor ownership |
