---
type: gotcha
project: namios
date: 2026-02-16
tags: [swiftui, ios, gesture, textselection]
---

# .onTapGesture on Parent Blocks .textSelection on Children (iOS)

## Trigger

Text selection via long-press doesn't work on iOS even though `.textSelection(.enabled)` is applied to the Text views.

## Root Cause

A parent view has `.onTapGesture { ... }` (e.g., to dismiss keyboard). On iOS, `.onTapGesture` on a parent **takes priority** over `.textSelection(.enabled)` on child views. The tap gesture recognizer intercepts touches before the text selection's long-press recognizer can activate.

This does NOT happen on macOS because text selection uses click-drag (not long-press), which doesn't conflict with tap gestures.

## Fix

Remove `.onTapGesture` from the parent. For keyboard dismissal, use:

```swift
ScrollView {
    // content with .textSelection(.enabled)
}
#if !os(macOS)
.scrollDismissesKeyboard(.interactively)
#endif
```

## Why Not `.simultaneousGesture`?

`.simultaneousGesture(TapGesture())` still interferes because the tap recognizer fires on touch-up, which can cancel the long-press before it's recognized.

## Additional Gotcha: `.textSelection` + `AttributedString` = Select-All Only

Even after fixing the gesture conflict, SwiftUI's `.textSelection(.enabled)` on `Text(AttributedString(...))` only supports **select-all** on iOS — no word-level selection with drag handles. This is a SwiftUI limitation as of iOS 17.

**Fix:** Use `UITextView` via `UIViewRepresentable` with `isEditable = false, isSelectable = true`. This gives native UIKit text selection with word-level handles. See `SelectableText.swift`.

## Key Insight

On iOS, gesture recognizer priority: parent `.onTapGesture` > child `.textSelection` long-press. Always prefer `.scrollDismissesKeyboard` over `.onTapGesture` for keyboard dismiss in scrollable chat views. And for partial text selection, use `UITextView` — SwiftUI `Text` doesn't support it with `AttributedString`.
