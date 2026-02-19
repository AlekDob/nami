---
type: bug-fix
project: namios
date: 2026-02-09
severity: high
tags: [push-notifications, APNs, macOS, AppKit, platform-specific]
---

# Fix: macOS APNs Registration Not Working (AppKit API)

## Symptom
Push notifications never received on macOS. Device token always `nil` even though `registerForRemoteNotifications()` was called.

## Root Cause
`PushNotificationManager.registerForRemoteNotifications()` only called:
```swift
UIApplication.shared.registerForRemoteNotifications()
```

`UIApplication` doesn't exist on macOS. The call either fails silently or crashes, preventing APNs registration. On macOS, the API is `NSApplication.shared.registerForRemoteNotifications()`.

## Solution
Use platform-specific APIs with conditional compilation:

```swift
private func registerForRemoteNotifications() {
    #if canImport(UIKit)
    UIApplication.shared.registerForRemoteNotifications()
    #elseif canImport(AppKit)
    NSApplication.shared.registerForRemoteNotifications()
    #endif
}
```

## File Modified
`/Users/alekdob/Desktop/Dev/Personal/namios-app-temp/Sources/Core/Network/PushNotificationManager.swift` (lines 78-83)

## Key Insight
**Platform abstractions**: Always use `#if canImport(UIKit)` / `#elseif canImport(AppKit)` to branch on frameworks, not OS names. This handles all Apple platforms correctly:
- iOS/iPadOS: `UIKit` available, use `UIApplication`
- macOS: `AppKit` available, use `NSApplication`
- Avoid `#if os(macOS)` because it's less clear about what framework you need

## Affected Platforms
- macOS 14+
