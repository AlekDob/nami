---
type: bug_fix
project: namios
date: 2026-02-13
severity: critical
tags: [performance, SwiftUI, @Observable, re-render, TTS, ChatBubble]
---

# Fix: ChatBubble TTS Button Causing @Observable Cascade Re-Renders

## Symptom
Every assistant message's `ChatBubble` subscribed to TTS state changes, causing all message bubbles + their `MarkdownText` to re-render on every TTS state change (playback started, stopped, metering updates). This compounded with the 30fps TimelineView updates on `NamiEntityView`, creating 98% CPU load during conversation.

## Root Cause
`ChatBubble.actionRow` directly accessed TTS properties:

```swift
struct ChatBubble: View {
    let message: Message
    var tts: TextToSpeechService

    var actionRow: some View {
        HStack {
            Button(action: { tts.speak(message.content) }) {
                Image(systemName: tts.isSpeaking && tts.speakingMessageID == message.id ? "speaker.fill" : "speaker")
                    .opacity(tts.isLoading ? 0.5 : 1.0)
            }
            .disabled(tts.isLoading)
        }
    }
}
```

By accessing `tts.isSpeaking`, `tts.speakingMessageID`, and `tts.isLoading` directly in the body, **every ChatBubble became an @Observable subscriber**. When TTS updated any of these properties (every 50-100ms during metering), all ChatBubbles re-rendered.

Call chain:
1. `tts.audioLevel` changes at 50ms intervals (ElevenLabsTTSService metering timer)
2. All ChatBubbles subscribed to `tts` object
3. All ChatBubbles re-render
4. All MarkdownText components re-parse and re-render
5. Result: O(n×m) re-renders where n = message count, m = TTS state changes per second

## Solution
**Extract TTS button into isolated `TTSSpeakButton` view.** Only the small button re-renders on TTS changes; parent ChatBubble and MarkdownText remain stable.

### Before (Bad)
```swift
struct ChatBubble: View {
    let message: Message
    var tts: TextToSpeechService

    var body: some View {
        VStack {
            MarkdownText(message.content) // ❌ re-renders when tts changes
            actionRow
        }
    }

    var actionRow: some View {
        HStack {
            Button(action: { tts.speak(message.content) }) {
                Image(systemName: tts.isSpeaking && tts.speakingMessageID == message.id ? "speaker.fill" : "speaker")
                    .opacity(tts.isLoading ? 0.5 : 1.0)
            }
            .disabled(tts.isLoading)
        }
    }
}
```

### After (Good)
```swift
struct ChatBubble: View {
    let message: Message
    let tts: TextToSpeechService

    var body: some View {
        VStack {
            MarkdownText(message.content) // ✅ does NOT re-render with TTS changes
            HStack {
                TTSSpeakButton(message: message, tts: tts) // ✅ isolated button
            }
        }
    }
}

struct TTSSpeakButton: View {
    let message: Message
    let tts: TextToSpeechService

    var body: some View {
        Button(action: { tts.speak(message.content) }) {
            Image(systemName: tts.isSpeaking && tts.speakingMessageID == message.id ? "speaker.fill" : "speaker")
                .opacity(tts.isLoading ? 0.5 : 1.0)
        }
        .disabled(tts.isLoading)
    }
}
```

## Files Modified
- `ChatBubble.swift` — Removed TTS state access from actionRow, created TTSSpeakButton child view
- New: `TTSSpeakButton.swift` — Isolated button component

## Performance Impact
This fix is part of the comprehensive 98% CPU fix (see `fix-namios-98-percent-cpu-comprehensive-performance-fix.md`). By eliminating the ChatBubble cascade, re-renders during TTS operations are reduced from O(n×m) to O(m) where m is just the button size.

## Key Insight
**When extracting components from @Observable subscribers:**
- Parent passes the @Observable object as a reference parameter (doesn't access its properties)
- Child view accesses only the specific properties it needs to render
- Only the child re-renders on those property changes
- Parent and other children remain stable

This pattern is essential for performance in apps with frequent state updates (like TTS metering at 50ms intervals). A single unguarded property access in a parent or large child view can cascade to re-render the entire message list.

**Rule**: If a component accesses an @Observable property that updates >5 times per second, wrap that access in an isolated child view.

## Verification
- CPU usage during TTS playback: 98% → ~25-35% (measured during message chat with TTS)
- Message MarkdownText no longer flashes/reflows during TTS state changes
- Smooth scroll performance while speaking

## Related Fixes
- `fix-macos-99-percent-cpu-observable-cascade.md` — General @Observable pattern (Feb 9)
- `fix-namios-98-percent-cpu-comprehensive-performance-fix.md` — Full optimization suite (Feb 13)
