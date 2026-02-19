---
type: pattern
title: SwiftUI Voice Input with SFSpeechRecognizer
tags: [swiftui, voice, speech-recognition, ios, audio]
date: 2026-02-02
status: verified
---

# SwiftUI Voice Input with SFSpeechRecognizer

Push-to-talk voice input using native `SFSpeechRecognizer` + `AVAudioEngine` with real-time transcript and waveform visualization.

## Architecture

```
SpeechRecognizer (@Observable)
  - AVAudioEngine
  - SFSpeechRecognizer
  - audioLevel: Float (0-1, for waveform)
  - transcript: String
      |
      +-- VoiceInputButton (mic button + waveform rings)
      +-- WaveformView (5 animated bars)
      +-- ChatViewModel.toggleVoiceInput()
```

## Key Components

### 1. SpeechRecognizer Service

```swift
@MainActor @Observable
final class SpeechRecognizer {
    var transcript = ""
    var isRecording = false
    var audioLevel: Float = 0

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "it-IT"))
    private var audioEngine = AVAudioEngine()

    func startRecording() {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.record, mode: .measurement)
        try? session.setActive(true, options: .notifyOthersOnDeactivation)
        #endif

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
            self.updateAudioLevel(buffer: buffer)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { result, error in
            if let result { self.transcript = result.bestTranscription.formattedString }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
    }

    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        isRecording = false
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif
    }

    private nonisolated func updateAudioLevel(buffer: AVAudioPCMBuffer) {
        guard let data = buffer.floatChannelData?[0] else { return }
        let count = Int(buffer.frameLength)
        var sum: Float = 0
        for i in 0..<count { sum += abs(data[i]) }
        let normalized = min(max((sum / Float(max(count, 1))) * 5, 0), 1)
        Task { @MainActor in self.audioLevel = normalized }
    }
}
```

### 2. Integration in ViewModel

```swift
func toggleVoiceInput() {
    if speechRecognizer.isRecording {
        speechRecognizer.stopRecording()
        if !speechRecognizer.transcript.isEmpty {
            inputText = speechRecognizer.transcript
        }
    } else {
        speechRecognizer.startRecording()
    }
}
```

## Required Permissions

```xml
<!-- Info.plist -->
<key>NSMicrophoneUsageDescription</key>
<string>Meow needs your microphone to hear your voice messages</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Meow uses speech recognition to convert your voice to text</string>
```

```xml
<!-- macOS entitlements -->
<key>com.apple.security.device.audio-input</key>
<true/>
```

## Gotchas

1. **Audio session conflicts** — If another app is playing audio, `setActive(true)` may fail
2. **Simulator has no mic** — Test on real device only
3. **`nonisolated` for audio buffer** — `updateAudioLevel()` called from audio thread, dispatch to `@MainActor`
4. **Cleanup is critical** — Always `removeTap()` + `setActive(false)` or you leak audio resources
5. **Permission timing** — Request permissions early (in init), not on first tap

## Related

- `decisions/decision-sfspeechrecognizer-before-whisperkit.md` — Why SFSpeechRecognizer over WhisperKit
- `bugs/fix-nsspeechrecognition-usage-description-crash.md` — Missing plist key crash
