---
type: bug-fix
project: namios
date: 2026-02-09
severity: critical
tags: [performance, infinite-loop, SwiftUI, @Observable, re-render, TimelineView, markdown-parsing, CPU, macOS]
---

# Fix: macOS 99% CPU Infinite Loop from @Observable Re-Renders

## Symptom
NamiOS macOS app hit 99% CPU immediately after launch. UI loaded but became unresponsive and unusable. CPU dropped only after force-quit.

## Root Cause
`ChatView` header accessed `viewModel.tts.audioLevel` directly in body:

```swift
struct ChatView: View {
    var viewModel: ChatViewModel

    var body: some View {
        VStack {
            MiniNamiView(audioLevel: viewModel.tts.audioLevel) // ❌ subscribed to audioLevel
            // ... rest of chat
        }
    }
}
```

In SwiftUI with `@Observable`, a view subscribes to properties it **accesses directly in its body**. This caused a cascade:

1. `ChatView` accessed `viewModel.tts.audioLevel`
2. `ChatView` subscribed to all changes to `tts`
3. When `TimelineView` in `NamiEntityView` updated at 30fps OR when TTS updated `audioLevel`, **entire ChatView re-rendered**
4. All `MessageRow` components re-rendered
5. All `MarkdownText` components re-parsed markdown (expensive operation)
6. Result: `30fps × heavy markdown parsing × all messages = 99% CPU`

## Solution
**Isolate @Observable property access to small child views.**

### Before (Bad)
```swift
struct ChatView: View {
    var viewModel: ChatViewModel

    var body: some View {
        VStack {
            MiniNamiView(audioLevel: viewModel.tts.audioLevel) // ❌ ChatView subscribes, cascades
        }
    }
}
```

### After (Good)
```swift
struct ChatView: View {
    var viewModel: ChatViewModel

    var body: some View {
        VStack {
            ChatHeaderNami(tts: viewModel.tts) // ✅ passes reference only
        }
    }
}

struct ChatHeaderNami: View {
    let tts: TextToSpeechService
    @State private var namiState: NamiState = .idle

    var body: some View {
        HStack {
            MiniNamiView(audioLevel: tts.audioLevel) // ✅ subscribes here, isolated re-renders
        }
        .onChange(of: tts.isSpeaking) { _, speaking in
            namiState = speaking ? .speaking : .idle
        }
    }
}
```

**Key pattern**:
- Parent passes `@Observable` object as reference parameter only (doesn't access its properties)
- Child view accesses the properties → only child re-renders when they change
- Re-renders are isolated to small component, not entire view hierarchy

### Implementation Steps
1. Created new `/Users/alekdob/Desktop/Dev/Personal/namios-app-temp/Sources/Features/Chat/ChatHeaderNami.swift`
2. Moved `namiState` computed property into `ChatHeaderNami`
3. Moved TTS/SpeechRecognizer property observations into `ChatHeaderNami`
4. Updated `ChatView` to only pass references:
   ```swift
   ChatHeaderNami(tts: viewModel.tts, speechRecognizer: viewModel.speechRecognizer, isThinking: viewModel.isThinking)
   ```

## Files Modified
- New: `/Users/alekdob/Desktop/Dev/Personal/namios-app-temp/Sources/Features/Chat/ChatHeaderNami.swift`
- Modified: `/Users/alekdob/Desktop/Dev/Personal/namios-app-temp/Sources/Features/Chat/ChatView.swift` (removed `namiState` computed property, replaced `MiniNamiView` usage with `ChatHeaderNami`)

## Performance Impact
- **Before**: 99% CPU, app unresponsive
- **After**: <5% CPU idle, smooth 60fps interactions

## Key Insight
**@Observable subscription model in SwiftUI**: A view subscribes to an object's properties only through **direct property access in its body**. Passing the object as a reference parameter does NOT create a subscription. This enables fine-grained reactivity:

- Coarse subscribers (parent views) can hold the object without reacting to all property changes
- Fine subscribers (small child views) access specific properties and re-render in isolation

This is why isolating property access to small child views is so powerful — the re-render cycle is bounded by the child's size and complexity, not the entire view tree.

**Never access frequently-updating @Observable properties in parent view bodies if possible.** Instead:
1. Pass the object as parameter to child
2. Child accesses the property
3. Only child re-renders

## Affected Platforms
- macOS (most visible due to higher frame rate on Mac displays)
- iOS (also benefits but less noticeable due to lower frame rates)
