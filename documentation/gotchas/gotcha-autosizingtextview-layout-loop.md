---
type: gotcha
project: namios
created: 2026-02-18
last_verified: 2026-02-18
tags: [macOS, NSTextView, layout, intrinsicContentSize, performance, SwiftUI, freeze]
---

# Gotcha: AutoSizingTextView layout→invalidateIntrinsicContentSize loop

## The Issue

When wrapping `NSTextView` in `NSViewRepresentable` for SwiftUI, a common pattern is to override `intrinsicContentSize` to report the text height. However, calling `invalidateIntrinsicContentSize()` inside `layout()` creates an infinite loop:

```
layout() → invalidateIntrinsicContentSize() → intrinsicContentSize → ensureLayout() → layout() → ...
```

For small text this completes quickly and stabilizes. For large text (200+ line code blocks, JSON, SQL), `ensureLayout()` is expensive enough that the loop saturates the CPU and freezes the app.

## The Problem

```swift
override func layout() {
    super.layout()
    textContainer?.containerSize = NSSize(width: bounds.width, height: .greatestFiniteMagnitude)
    invalidateIntrinsicContentSize() // triggers another layout pass EVERY time
}
```

## The Fix

Track the last known width. Only invalidate when width actually changes:

```swift
private var lastLayoutWidth: CGFloat = -1

override func layout() {
    super.layout()
    let currentWidth = bounds.width
    guard currentWidth != lastLayoutWidth else { return }
    lastLayoutWidth = currentWidth
    textContainer?.containerSize = NSSize(width: currentWidth, height: .greatestFiniteMagnitude)
    invalidateIntrinsicContentSize()
}

override func didChangeText() {
    super.didChangeText()
    lastLayoutWidth = -1  // force recalculation on text change
    invalidateIntrinsicContentSize()
}
```

## Also Cache NSAttributedString

If the `NSViewRepresentable.updateNSView()` is called on every SwiftUI body evaluation, the `NSAttributedString` should be cached. Without caching, every re-render rebuilds attributed strings from scratch — expensive for markdown with inline formatting (bold, italic, links, code).

Use `NSCache<NSString, NSAttributedString>` keyed by content + font.

## Also: Check the Parent View Tree

Even with the layout guard in place, if a **parent view** (e.g. ContentView) reads an `@Observable` property in its `body`, SwiftUI will re-evaluate the entire hierarchy on every change — including all `NSViewRepresentable` wrappers. This triggers `updateNSView` on every mutation, which can bypass your guards if it calls `invalidateIntrinsicContentSize()` directly.

**Symptoms**: `[ContentView] body evaluated` prints in a loop, 100% CPU, even after fixing the NSTextView layout loop.

**Fix**: Isolate `@Observable` property access into wrapper views. Never read `@Observable` properties from a root-level view that contains expensive subviews. See `fix-macos-freeze-long-code-blocks.md` cause #6.

## Also: Disable ALL Automatic Text Checking

`NSTextView` has automatic features (`isAutomaticLinkDetectionEnabled`, `isAutomaticDashSubstitutionEnabled`, etc.) that **modify the textStorage** asynchronously — adding `.link` attributes, replacing dashes with em-dashes, etc. Each modification triggers `didChangeText()`, which resets the `lastLayoutWidth` guard and restarts the layout loop.

This is especially insidious because it bypasses the width guard and causes freezes **even on small messages** (< 500 chars) if they contain URLs or special characters.

**Fix**: Disable all automatic text checking. If you need links to be clickable, add `.link` attributes in the `NSAttributedString` **before** setting it on the textView. `NSTextView` with `isEditable = false` clicks `.link` attributes natively — no automatic detection needed.

```swift
textView.isAutomaticLinkDetectionEnabled = false
textView.isAutomaticTextReplacementEnabled = false
textView.isAutomaticDashSubstitutionEnabled = false
textView.isAutomaticQuoteSubstitutionEnabled = false
textView.isAutomaticSpellingCorrectionEnabled = false
textView.isAutomaticTextCompletionEnabled = false
```

## Prevention Checklist

- [ ] Never call `invalidateIntrinsicContentSize()` unconditionally in `layout()`
- [ ] Track previous width/height and only invalidate on actual change
- [ ] Reset the width tracker in `didChangeText()` so text changes are reflected
- [ ] Cache `NSAttributedString` outputs in a static `NSCache`
- [ ] In `updateNSView`, compare content before updating — skip if unchanged
- [ ] Check parent views for @Observable subscriptions that trigger unnecessary re-renders
- [ ] **Disable ALL automatic text checking** — link detection, dash/quote substitution, spell correction
- [ ] Test with large content (200+ lines) on macOS — iOS `UITextView` doesn't have this issue
- [ ] Test with small messages containing URLs — link detection causes freezes even on tiny text

## Nuclear Option: Drop NSTextView

If all the above patches don't solve the freeze, the root cause is architectural: `NSTextView.ensureLayout()` is fundamentally incompatible with SwiftUI's reactive rendering. SwiftUI can request `intrinsicContentSize` many times per layout pass, and `ensureLayout()` is expensive. Replace `NSViewRepresentable` + `AutoSizingTextView` with native `Text(AttributedString)` + `.textSelection(.enabled)`. Convert `NSAttributedString` → `AttributedString` manually (enumerate attributes, map font/color/link). Cache the conversion.

**Trade-off**: loses word-level selection (only select-all). Links remain clickable.

## Platforms

- macOS 14+ (NSTextView + SwiftUI via NSViewRepresentable) — **avoid, use SwiftUI Text instead**
- Not applicable to iOS (UITextView handles sizing differently via `sizeThatFits`)
