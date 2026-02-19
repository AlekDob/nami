---
type: bug_fix
project: namios
created: 2026-02-18
last_verified: 2026-02-18
severity: critical
tags: [performance, macOS, NSTextView, layout-loop, NSCache, regex, freeze, code-blocks]
---

# Fix: macOS freeze on long messages with code blocks (JSON/SQL)

## Problem

NamiOS macOS app freezes completely when a chat message contains large code blocks (JSON arrays, SQL queries). The app becomes unresponsive and must be force-quit. Reloading the same session afterward works fine because caches are warm.

## Root Causes (7 compounding issues + 1 architectural fix)

### 1. AutoSizingTextView layout→invalidate loop (CRITICAL)

`SelectableText.swift` — `AutoSizingTextView.layout()` called `invalidateIntrinsicContentSize()` unconditionally on every layout pass. Since `intrinsicContentSize` calls `layoutManager.ensureLayout(for:)`, and `invalidateIntrinsicContentSize()` triggers another layout pass, this creates a loop:

```
layout() → invalidateIntrinsicContentSize() → intrinsicContentSize → ensureLayout() → layout() → ...
```

For a CodeBlockView with 200+ lines of JSON, `ensureLayout()` is extremely expensive. NSScrollView can trigger this cycle multiple times per frame.

**Fix**: Track `lastLayoutWidth` and only invalidate when width actually changes.

### 2. nsAttributedString() not cached (HIGH)

`MarkdownText.swift` — the `nsAttributedString()` method builds an `NSAttributedString` from scratch on every SwiftUI body evaluation. Block parsing was cached via `NSCache`, but the inline markdown→attributed string conversion was not. Every re-render recomputed bold/italic/link/code formatting for all text blocks.

**Fix**: Added `NSCache<NSString, NSAttributedString>` keyed by `text|fontName|fontSize`.

### 3. URL regex triggered on every "h" character (HIGH)

`MarkdownText.swift` — the plain-text scanner stopped at every character that could start a URL, using `$0 == "h"` as the trigger. This meant every word starting with "h" (the, this, that, have, here, he, her...) caused:
1. Stop scanning plain text
2. Create `String(remaining)` — full copy of remaining text
3. Run `NSRegularExpression.firstMatch()` on it
4. Fail to match (not a URL), resume

In a 5KB message with 50+ words starting with "h", this was dozens of unnecessary regex evaluations with full string copies.

**Fix**: Changed URL detection to only trigger on `"http://"` or `"https://"` prefix (7-8 char check), not bare `"h"`. Plain text scanner no longer stops at "h".

### 4. updateNSView bypasses layout guard (CRITICAL)

`SelectableText.swift` — `updateNSView` called `invalidateIntrinsicContentSize()` directly, bypassing the `lastLayoutWidth` guard in `layout()`. This was called on **every SwiftUI re-render**, even when the attributed string hadn't changed. Combined with the spring animation (cause #5), this triggered expensive `ensureLayout()` calls on every animation frame.

**Fix**: Compare `textStorage.string` with incoming `attributedString.string` — skip update entirely if content is identical. When content does change, call `resetLayoutWidth()` instead of `invalidateIntrinsicContentSize()` directly.

### 5. Spring entrance animation on macOS (HIGH)

`MessageRow.swift` — new messages appeared with `.spring(response: 0.35, dampingFraction: 0.8)` animating `opacity` and `offset`. During the animation, SwiftUI may re-evaluate the view body on each frame. On iOS, `UITextView.sizeThatFits` is fast. On macOS, each frame triggers `AutoSizingTextView.layout()` → `ensureLayout()` — expensive for any non-trivial text.

**Fix**: Disabled spring animation on macOS entirely (`#if os(macOS) appeared = true`). Messages appear instantly. iOS keeps the spring animation since UITextView doesn't have this issue.

### 6. ContentView @Observable cascade re-renders ALL tabs (CRITICAL)

`ContentView.swift` — ContentView's `tabContent(for:)` method read `chatVM?.currentSessionId` directly in the `.chat` case. Since `ChatViewModel` is `@Observable`, reading **any** property in a view's body creates an implicit subscription to **all** changes on that object. Every new message, every `isThinking` toggle, every `currentSessionId` update caused ContentView to re-evaluate its entire body — including **all tabs**, not just the active one.

This meant MarkdownText, AutoSizingTextView, and CodeBlockView were being reconstructed on every single ChatViewModel mutation, even when the user was on a completely different tab.

**Fix**: Created `SessionListContainer` wrapper view (inline in ContentView.swift) that isolates the `chatVM.currentSessionId` access. ContentView no longer reads any `@Observable` property from `chatVM` in its body, breaking the cascade. Also added **deferred markdown rendering** in `ChatBubble.swift` — messages > 500 chars show plain `Text` first, then swap to `MarkdownText` after 50ms, preventing the initial render from overwhelming the layout system.

### 7. NSTextView automatic link detection modifies textStorage (CRITICAL)

`SelectableText.swift` — `isAutomaticLinkDetectionEnabled = true` causes NSTextView to run `NSDataDetector` on the text, **modifying the textStorage** to add `.link` attributes. This triggers `didChangeText()` → `lastLayoutWidth = -1` → `invalidateIntrinsicContentSize()` → layout loop restart. Even with the layout guard (cause #1), the link detector **resets the guard** by going through `didChangeText()`.

This caused freezes even on **small messages** (452 chars) if they contained URLs (e.g. x.com links). The link detection is redundant because `buildAttributedString()` already creates `.link` attributes for all URLs.

Other automatic text features (`isAutomaticTextReplacementEnabled`, `isAutomaticDashSubstitutionEnabled`, `isAutomaticQuoteSubstitutionEnabled`, `isAutomaticSpellingCorrectionEnabled`, `isAutomaticTextCompletionEnabled`) can also modify textStorage and were disabled as a precaution.

**Fix**: Disabled all automatic text checking. Links with `.link` attribute are still clickable on `NSTextView` with `isEditable = false`.

### 8. Definitive fix: drop NSTextView entirely on macOS (ARCHITECTURAL)

After fixing 7 causes, the app still froze. The fundamental problem is that `NSTextView.ensureLayout()` is incompatible with SwiftUI's reactive rendering model. Every re-render path — `intrinsicContentSize`, `layout()`, `updateNSView`, automatic text checking — can trigger `ensureLayout()`, and SwiftUI can request `intrinsicContentSize` many times per layout pass. Patching individual triggers is a game of whack-a-mole.

**Fix**: Replaced `NSViewRepresentable` + `AutoSizingTextView` on macOS with native `SwiftUI.Text(AttributedString)` + `.textSelection(.enabled)`. The `NSAttributedString` from `MarkdownText` is manually converted to `AttributedString` preserving font, color, and link attributes. Cached with `NSCache`.

**Trade-off**: macOS loses word-level text selection (only select-all via ⌘A). Links remain clickable. iOS is unchanged (still uses `UITextView`).

## Files Modified

| File | Change |
|------|--------|
| `Sources/Core/Design/SelectableText.swift` | **Definitive**: replaced `NSViewRepresentable` + `AutoSizingTextView` with SwiftUI `View` using `Text(AttributedString)` + `.textSelection(.enabled)`. Manual NSAttributedString→AttributedString conversion with NSCache. Previous incremental fixes (layout guard, content-equality check, disable auto text checking) are now moot — NSTextView is gone entirely on macOS |
| `Sources/Core/Design/MarkdownText.swift` | Added `NSCache` for attributed strings, split `nsAttributedString` into cached wrapper + `buildAttributedString`, fixed URL regex trigger |
| `Sources/Core/Design/MarkdownExtras.swift` | Added `NSCache` for `CodeBlockView.codeAttributedString` |
| `Sources/Features/Chat/MessageRow.swift` | Disabled spring entrance animation on macOS |
| `Sources/ContentView.swift` | Created `SessionListContainer` wrapper to isolate @Observable subscription; ContentView no longer reads `chatVM` properties in body |
| `Sources/Core/Design/ChatBubble.swift` | Deferred markdown rendering on macOS — plain Text first for messages > 500 chars, swap to MarkdownText after 50ms |

## Why Reload Worked

After force-quit and reload:
- Messages loaded with `skipEntrance: true` (no animation)
- `NSCache` for block parsing already warm from initial render
- `AutoSizingTextView` layout stabilized after initial size computation
- The loop still existed but ran fewer iterations with stable container width

## Related

- `fix-macos-99-percent-cpu-observable-cascade.md` — Feb 9 fix for @Observable cascade
- `fix-scroll-freeze-lazyvstack-animation-cascade.md` — Feb 13 fix for .animation() on LazyVStack
- This is the **third round** of macOS performance fixes, all stemming from expensive operations inside SwiftUI's reactive rendering pipeline
