---
title: Missing NSSpeechRecognitionUsageDescription causes crash
date: 2026-02-02
type: bug
tags: [ios, permissions, crash, info-plist]
severity: critical
status: fixed
---

# Missing NSSpeechRecognitionUsageDescription causes crash

## Symptom

App crashes immediately after Face ID unlock with error:

```
This app has crashed because it attempted to access privacy-sensitive data without a usage description.
The app's Info.plist must contain an NSSpeechRecognitionUsageDescription key...
```

## Root Cause

`SpeechRecognizer.requestPermissions()` was called in `ChatViewModel.init()` **before** the `Info.plist` contained the required `NSSpeechRecognitionUsageDescription` key.

iOS enforces this at runtime — any access to `SFSpeechRecognizer.requestAuthorization()` triggers a plist check, and crashes if missing.

## Why it happened

The voice input feature was implemented in two steps:
1. First, code was written (`SpeechRecognizer.swift` + integration)
2. Later, permissions were added to `Info.plist`

The app built successfully (no compile-time check for plist keys), but crashed at runtime when `requestPermissions()` was invoked.

## Fix

Add both microphone **and** speech recognition keys to `Sources/Info.plist`:

```xml
<key>NSMicrophoneUsageDescription</key>
<string>Meow needs your microphone to hear your voice messages</string>
<key>NSSpeechRecognitionUsageDescription</key>
<string>Meow uses speech recognition to convert your voice to text</string>
```

Also add to `project.yml` if using xcodegen:

```yaml
targets:
  MeowApp_iOS:
    info:
      path: Sources/Info.plist
      properties:
        NSMicrophoneUsageDescription: "Meow needs your microphone to hear your voice messages"
        NSSpeechRecognitionUsageDescription: "Meow uses speech recognition to convert your voice to text"
```

## Prevention

When adding a new iOS privacy-sensitive API, **always add the usage description to `Info.plist` BEFORE writing the code** that accesses it.

Privacy-sensitive APIs (incomplete list):
- Microphone → `NSMicrophoneUsageDescription`
- Speech Recognition → `NSSpeechRecognitionUsageDescription`
- Camera → `NSCameraUsageDescription`
- Photo Library → `NSPhotoLibraryUsageDescription`
- Location → `NSLocationWhenInUseUsageDescription`
- Contacts → `NSContactsUsageDescription`
- Calendar → `NSCalendarsUsageDescription`
- Face ID → `NSFaceIDUsageDescription` (already in project)
