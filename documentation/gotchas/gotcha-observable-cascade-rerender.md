---
type: gotcha
project: namios
date: 2026-02-09
tags: [SwiftUI, @Observable, performance, re-render, state-management]
---

# Gotcha: SwiftUI @Observable Cascade Re-Renders

## The Issue
Accessing `@Observable` properties in a parent view body creates subscriptions that trigger re-renders of the **entire view hierarchy**, even if only a small child view needs to react to changes.

## Example: The Problem

```swift
struct ChatView: View {
    var viewModel: ChatViewModel  // @Observable

    var body: some View {
        VStack {
            MiniNamiView(audioLevel: viewModel.tts.audioLevel) // ❌ subscribes here

            // ... 100+ MessageRow views, each with markdown parsing
        }
    }
}
```

When `tts.audioLevel` changes (e.g., during TTS playback), SwiftUI re-renders:
1. **ChatView** (accessed `audioLevel` in body)
2. **All MessageRow children** (entire scroll view)
3. **All MarkdownText children** (re-parse markdown for every message!)
4. Result: Heavy CPU spike, unresponsive UI

**Real-world impact**: 30fps audio level updates × markdown parsing for 50 messages = 99% CPU, app unusable.

## The Culprit: Subscription Model
SwiftUI with `@Observable` uses **property-level subscriptions**. A view subscribes to an object only through **direct property access in its body**:

```swift
// ❌ ChatView accessing tts.audioLevel creates subscription to tts
var body: some View {
    MiniNamiView(audioLevel: viewModel.tts.audioLevel) // subscribes!
}

// ✅ ChatView NOT accessing tts properties = no subscription
var body: some View {
    ChatHeaderNami(tts: viewModel.tts) // passes reference only
}
```

## The Solution: Isolate Access to Child Views

```swift
struct ChatView: View {
    var viewModel: ChatViewModel

    var body: some View {
        VStack {
            ChatHeaderNami(tts: viewModel.tts) // ✅ passes reference only
            // ... messages (don't re-render when tts.audioLevel changes)
        }
    }
}

struct ChatHeaderNami: View {
    let tts: TextToSpeechService

    var body: some View {
        HStack {
            MiniNamiView(audioLevel: tts.audioLevel) // ✅ subscribes here (small view)
            Text("Listening...")
        }
    }
}
```

Now when `audioLevel` changes:
1. Only **ChatHeaderNami** re-renders (small, fast)
2. **ChatView** and its 100+ **MessageRow** children are not affected
3. Re-render is bounded by child's complexity, not parent tree

## Why This Happens
`@Observable` properties are **reactive at access time**, not declaration time. The moment you read a property in SwiftUI body, that view becomes a subscriber. Parent views that DON'T access the property are not subscribers.

## Prevention Checklist
- [ ] Parent views hold `@Observable` objects but **don't access their properties** in body
- [ ] Child views access the properties they care about
- [ ] If parent needs to monitor state, use computed properties or `onChange` instead
- [ ] Frequently-updating properties (audio levels, animations) should be accessed only in small, focused child views
- [ ] Test with Xcode Instruments: "Core Animation" tool shows re-render frequency

## Affected Scenarios
- Real-time audio visualization (TTS playback, speech recognition)
- Animation state updates (TimelineView at 30+ fps)
- Model streaming (tokens updating rapidly)
- Any high-frequency property changes

## Platforms
- iOS 17+
- macOS 14+
- SwiftUI with @Observable macro
