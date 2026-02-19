---
type: decision
title: Start with SFSpeechRecognizer before WhisperKit for Phase 2
tags: [voice, speech-recognition, architecture, mvp]
date: 2026-02-02
status: active
---

# Decision: Start with SFSpeechRecognizer before WhisperKit

## Context

For Phase 2 (STT), two options: **SFSpeechRecognizer** (Apple native) vs **WhisperKit** (Argmax open-source, Neural Engine).

## Decision

**Use `SFSpeechRecognizer` for Phase 2a (MVP voice input), defer WhisperKit to Phase 2c (optional migration).**

## Rationale

### Why SFSpeechRecognizer first?
1. **Zero setup** — Already in iOS SDK, no model download
2. **Instant availability** — Works immediately after permission grant
3. **Excellent accuracy** — Apple's models tuned for 100+ languages including Italian
4. **Free** — No API costs, no quota limits
5. **On-device** — Privacy guaranteed, works offline
6. **Smaller footprint** — No 150MB model in app bundle

### Why defer WhisperKit?
1. **Complexity** — Requires model download UI, storage management (150MB), warmup time
2. **Not needed yet** — SFSpeechRecognizer already works offline on-device
3. **Can swap later** — `SpeechRecognizer` service is isolated; swapping backend doesn't affect UI

## Implementation Path

- **Phase 2a (DONE)** — SFSpeechRecognizer MVP with waveform animation
- **Phase 2b (Next)** — Haptic feedback, error handling UI, waveform improvements
- **Phase 2c (Optional)** — WhisperKit migration, A/B test accuracy

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| SFSpeechRecognizer fails for some users | Fallback to text input + error message |
| Apple changes API in iOS 18+ | Abstract behind `SpeechRecognizer` protocol |
| Users want offline with no Apple dependency | Implement WhisperKit in Phase 2c |

## Related

- `patterns/pattern-swiftui-voice-input-sfspeechrecognizer.md` — Implementation details
