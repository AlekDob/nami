---
title: "@Observable Cascade + MarkdownText Causes macOS Scroll Freeze"
date: 2026-02-15
type: bug
tags: [swiftui, observable, macos, scroll, performance, tts, attributedstring]
severity: high
status: fixed
---

# Bug: @Observable Cascade + MarkdownText Freezes macOS Chat Scroll

## Symptom
Scrolling through long conversations (50+ messages) on macOS causes the app to freeze. Works fine on iPhone. CPU spikes during scroll.

## Root Cause: 3 Combined Issues

### 1. TTS @Observable Leaking Into Every ChatBubble (CRITICAL)

`ChatView` passed `tts: viewModel.tts` to ALL MessageRow instances. `TextToSpeechService` is `@Observable`, so SwiftUI tracked it as a dependency for every row. Any TTS state change re-rendered ALL messages.

```swift
// BEFORE — tts passed to ALL rows
ForEach(viewModel.messages) { message in
    MessageRow(tts: viewModel.tts, ...)  // @Observable leak!
}
```

### 2. `.textSelection(.enabled)` on macOS

On macOS, `.textSelection(.enabled)` wraps each Text in `NSTextView` that intercepts scroll/mouse events. Massive overhead during scroll.

### 3. MarkdownText: Text Concatenation vs AttributedString

`styledInlineText()` used `Text("a") + Text("b").bold()` concatenation. For long messages, this created deep `Text` trees. Replaced with single `AttributedString`.

## Fix

```swift
// AFTER — only latest message gets @Observable objects
let lastMsgID = viewModel.messages.last?.id
ForEach(viewModel.messages) { message in
    let isLatest = message.id == lastMsgID
    MessageRow(
        stats: isLatest ? viewModel.lastStats : nil,
        toolsUsed: isLatest ? viewModel.lastToolsUsed : nil,
        tts: isLatest ? viewModel.tts : nil,  // only latest!
        ...
    )
}
```

```swift
// ChatBubble.swift — textSelection disabled on macOS
#if !os(macOS)
.textSelection(.enabled)
#endif
```

```swift
// MarkdownText.swift — AttributedString instead of Text concatenation
private func styledAttributedString(_ text: String) -> AttributedString {
    var result = AttributedString()
    // ... same parsing logic, append AttributedString instead of Text+Text
    return result
}
// Usage: Text(styledAttributedString(text))  // single Text view
```

## Files Changed
- `Sources/Features/Chat/ChatView.swift` — only pass observables to latest message
- `Sources/Core/Design/ChatBubble.swift` — disable textSelection on macOS
- `Sources/Core/Design/MarkdownText.swift` — AttributedString rewrite

## Why macOS but Not iOS?
- `NSScrollView` is more CPU-bound during scroll than `UIScrollView`
- `NSTextView` wrapping from `.textSelection` adds overhead on macOS
- macOS SwiftUI rendering pipeline is less tolerant of expensive view bodies

## Lesson
With `@Observable`, passing an observable object as a parameter to a view creates an implicit subscription — even if the view never reads its properties. Pass `nil` to views that don't need the observable data. Pre-compute values outside ForEach to avoid per-row @Observable access.

## Related
- `gotchas/gotcha-observable-cascade-rerender.md` — General @Observable gotcha
- `bugs/fix-macos-99-percent-cpu-observable-cascade.md` — Earlier related CPU fix
