---
type: bug_fix
project: namios
date: 2026-02-13
severity: critical
tags: [performance, SwiftUI, LazyVStack, animation, scroll-freeze, textSelection, MessageRow, CPU]
---

# Fix: Scroll freeze (100% CPU) when scrolling pre-loaded chat messages

## Problem

NamiOS freezes completely (100% + 99.2% CPU, two processes) when scrolling through a conversation loaded from SwiftData persistence. The app becomes unresponsive immediately upon scrolling. Test case: 5 messages with content sizes [34, 750, 214, 752, 117] — messages containing tables, code blocks, and complex markdown.

## Root Causes (4 compounding issues)

### 1. `.animation()` on LazyVStack (ChatView.swift:129-130)

Two `.animation()` modifiers applied to the entire LazyVStack content:
- `.animation(.easeInOut(duration: 0.2), value: viewModel.isThinking)`
- `.animation(.easeInOut(duration: 0.15), value: viewModel.activeTools.count)`

When SwiftUI applies implicit animations to a LazyVStack, it must compute layout diffs for ALL visible children during animation transactions. With heavy markdown content (tables, code blocks), this causes catastrophic layout passes.

### 2. `.spring()` entrance animation on every MessageRow (MessageRow.swift:49-53)

Every MessageRow starts with `opacity: 0` and `offset(y: 8)`, then animates in with `.spring(response: 0.35, dampingFraction: 0.8)` on `onAppear`. When loading 5 pre-persisted messages, ALL 5 fire `onAppear` simultaneously during scroll, causing 5 concurrent spring animations with heavy markdown layout passes.

### 3. Duplicate `.textSelection(.enabled)` (nested levels)

`.textSelection(.enabled)` was applied at three nested levels:
- ChatBubble.swift:56 (parent)
- MarkdownText.swift:18 (child)
- CodeBlockView.swift:126 (grandchild)

Each `.textSelection` modifier creates text interaction infrastructure. Nested text selection is known to be expensive in SwiftUI, especially with complex VStack hierarchies containing multiple Text views.

### 4. `Array(viewModel.messages.enumerated())` in ForEach (ChatView.swift:96)

Creates a new Array allocation on every body evaluation of messagesList. While not the primary cause, it adds unnecessary overhead during scroll when SwiftUI re-evaluates the view tree.

## Solution

### 1. Removed `.animation()` from LazyVStack

Transitions for thinking indicator and tool pills now rely only on their local `.transition()` modifiers, which are scoped to the specific views being inserted/removed.

### 2. Added `skipEntrance` parameter to MessageRow

Pre-loaded messages (all except the latest) set `skipEntrance = true` immediately without animation. Only the most recently added message gets the spring entrance animation. This prevents N concurrent spring animations when loading persisted conversations.

### 3. Removed duplicate `.textSelection(.enabled)`

Removed from MarkdownText and CodeBlockView — keeping it only on the parent ChatBubble, which is sufficient for text selection to work on all child Text views.

### 4. Replaced `ForEach(Array(enumerated()))` with `ForEach(messages)`

Using ChatMessage's Identifiable conformance directly, avoiding the Array allocation. Used `message.id == viewModel.messages.last?.id` instead of index comparison for `isLatest`.

## Files Modified

| File | Change |
|------|--------|
| `Sources/Features/Chat/ChatView.swift` | Removed .animation() modifiers, simplified ForEach, added skipEntrance parameter |
| `Sources/Features/Chat/MessageRow.swift` | Added skipEntrance parameter, conditional animation |
| `Sources/Core/Design/MarkdownText.swift` | Removed .textSelection(.enabled) |
| `Sources/Core/Design/MarkdownExtras.swift` | Removed .textSelection(.enabled) from CodeBlockView |

## Performance Impact

| Metric | Before | After |
|--------|--------|-------|
| CPU (scroll) | 100% + 99.2% (two processes) | Normal usage |
| App responsiveness | Completely frozen | Smooth scrolling |
| Scroll frame rate | 0 fps (stalled) | 60 fps (smooth) |

## Key Insight

Never apply `.animation()` modifiers to LazyVStack or any lazy container. Implicit animations on lazy containers force SwiftUI to compute animated layout diffs for all visible children, which is catastrophic when children contain expensive views (markdown rendering, tables, code blocks). Use scoped `.transition()` on individual inserting/removing views instead.

## Related

This is a follow-up to the Feb 9 fix for @Observable cascade re-renders (`fix-macos-99-percent-cpu-observable-cascade.md`). The Feb 9 fix addressed continuous CPU drain from TimelineView + audioLevel subscriptions. This Feb 13 fix addresses scroll-triggered CPU spikes from animation + layout overhead.

Together, these two fixes resolved a two-stage performance degradation:
1. **Round 1 (Feb 9)**: Continuous background CPU drain
2. **Round 2 (Feb 13)**: Scroll-triggered UI freeze

Both issues stemmed from SwiftUI reactivity patterns applied incorrectly to expensive views.
