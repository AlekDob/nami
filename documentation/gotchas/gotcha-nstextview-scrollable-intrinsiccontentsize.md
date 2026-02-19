---
type: gotcha
project: namios
date: 2026-02-16
tags: [macos, nstextview, nsviewrepresentable, swiftui, layout]
---

# NSTextView.scrollableTextView() Breaks intrinsicContentSize in SwiftUI

## Symptom
Text rendered via `NSViewRepresentable` wrapping `NSTextView.scrollableTextView()` appears invisible on macOS — 0 height. Copy/TTS buttons visible, but text body collapsed.

## Root Cause
`NSTextView.scrollableTextView()` wraps the text view in an `NSScrollView`. The `NSScrollView` does not communicate `intrinsicContentSize` to SwiftUI's layout engine. Manual `scrollView.frame.size.height` assignments in `updateNSView` are ignored.

## Fix
Replace `NSTextView.scrollableTextView()` with a standalone `NSTextView` subclass (`AutoSizingTextView`) that overrides `intrinsicContentSize` to return the actual text layout height:

```swift
class AutoSizingTextView: NSTextView {
    override var intrinsicContentSize: NSSize {
        guard let layoutManager, let textContainer else {
            return super.intrinsicContentSize
        }
        layoutManager.ensureLayout(for: textContainer)
        let rect = layoutManager.usedRect(for: textContainer)
        return NSSize(width: NSView.noIntrinsicMetric, height: rect.height)
    }
}
```

SwiftUI reads `intrinsicContentSize` correctly from this subclass.

## Rule
Never use `NSTextView.scrollableTextView()` in `NSViewRepresentable`. Always use a standalone `NSTextView` with `intrinsicContentSize` override when SwiftUI needs to size the view.

## Related
- `Sources/Core/Design/SelectableText.swift` (macOS impl)
