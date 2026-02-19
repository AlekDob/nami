---
type: gotcha
project: namios
date: 2026-02-13
tags: [SwiftUI, LazyVStack, animation, performance, scroll-freeze]
---

# Gotcha: Never use .animation() on LazyVStack — causes scroll freeze

## The Issue

Applying `.animation(value:)` modifiers to a `LazyVStack` (or any lazy container) causes SwiftUI to compute animated layout diffs for ALL visible children when the tracked value changes. If children are expensive (markdown rendering, tables, images), this freezes the UI.

## Example — The Problem

```swift
LazyVStack {
    ForEach(messages) { message in
        MessageRow(message: message) // contains MarkdownText, tables, code blocks
    }
    if isThinking { ThinkingIndicator() }
}
.animation(.easeInOut(duration: 0.2), value: isThinking) // CATASTROPHIC
.animation(.easeInOut(duration: 0.15), value: activeTools.count) // CATASTROPHIC
```

When `isThinking` changes, SwiftUI animates the diff of the entire LazyVStack — measuring and laying out every visible MessageRow (with full markdown parsing) during the animation. This causes 100%+ CPU usage and UI freeze.

## Example — The Fix

```swift
LazyVStack {
    ForEach(messages) { message in
        MessageRow(message: message)
    }
    if isThinking {
        ThinkingIndicator()
            .transition(.opacity) // scoped to this view only
            .id("thinking-indicator")
    }
}
// NO .animation() on the container
```

Use `.transition()` on the specific views being inserted/removed. Transitions are scoped to their view and don't affect siblings.

## Also Applies To

- `.animation()` on ScrollView
- `.animation()` on List
- `.animation()` on any parent of a lazy container
- Multiple `.onAppear` animations firing simultaneously when loading pre-existing data

## Prevention Checklist

- [ ] Never apply .animation() to LazyVStack, LazyHGrid, List, or their parent ScrollView
- [ ] Use .transition() on individual inserting/removing views
- [ ] Skip entrance animations for pre-loaded data (use a flag like `skipEntrance`)
- [ ] Keep .textSelection(.enabled) at ONE level only (outermost container)
- [ ] Profile with Instruments > SwiftUI > View Body calls to detect excessive re-evaluations

## Why This Matters

LazyVStack is designed to defer layout until views are visible. When you apply `.animation()` to the container, you break this optimization — SwiftUI must compute the animated layout state for all visible children simultaneously. With expensive children (markdown with tables, code blocks), this is catastrophic.

Scoped `.transition()` modifiers preserve the lazy evaluation model and only animate the views being inserted/removed.
