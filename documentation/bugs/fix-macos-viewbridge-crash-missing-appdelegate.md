---
type: bug-fix
project: namios
date: 2026-02-09
severity: critical
tags: [crash, ViewBridge, AppDelegate, push-notifications, race-condition, macOS, iOS]
---

# Fix: macOS ViewBridge Crash on App Launch (Missing NSApplicationDelegateAdaptor)

## Symptom
NamiOS macOS app crashed immediately on launch with:
```
ViewBridge to RemoteViewService Terminated: Error Domain=com.apple.ViewBridge Code=18
```
App crashed before UI appeared.

## Root Cause
`MeowApp.swift` only had `UIApplicationDelegate` for iOS, with no macOS delegate. macOS SwiftUI apps require `NSApplicationDelegate` to handle:
- Lifecycle events
- Push notification registration callbacks
- Remote notification token delivery

Without a macOS delegate, the app couldn't register for APNs or respond to system events, causing ViewBridge (the UIKit-macOS bridge in Catalyst/Mac apps) to crash.

## Solution

### 1. Create MacAppDelegate (MeowApp.swift)
Added `MacAppDelegate` class that implements `NSApplicationDelegate`:

```swift
#if canImport(AppKit)
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    var pushManager: PushNotificationManager? {
        didSet {
            if let pushManager, let pending = pendingToken {
                pendingToken = nil
                Task { @MainActor in
                    pushManager.handleDeviceToken(pending)
                }
            }
        }
    }
    private var pendingToken: Data?

    func applicationDidBecomeActive(_ notification: Notification) {
        // Called when app becomes active
    }

    func application(
        _ application: NSApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            if let pm = pushManager {
                pm.handleDeviceToken(deviceToken)
            } else {
                print("[MacAppDelegate] APNs token arrived before pushManager — queuing")
                pendingToken = deviceToken
            }
        }
    }

    func application(
        _ application: NSApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("[MacAppDelegate] Failed to register for remote notifications: \(error)")
    }
}
#endif
```

### 2. Attach Delegate to macOS App (MeowApp.swift)
```swift
@main
struct MeowApp: App {
    #if os(iOS)
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    #elseif os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var appDelegate
    #endif

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 3. Handle Race Condition: Pending Token Queue
APNs token callback can arrive before `pushManager` is assigned (e.g., if app already had permission from previous launch). Use `didSet` observer to flush pending token:

```swift
var pushManager: PushNotificationManager? {
    didSet {
        if let pushManager, let pending = pendingToken {
            pendingToken = nil
            Task { @MainActor in
                pushManager.handleDeviceToken(pending)
            }
        }
    }
}
```

### 4. Update PushNotificationManager.registerForRemoteNotifications()
Register with platform-specific API:

```swift
private func registerForRemoteNotifications() {
    #if canImport(UIKit)
    UIApplication.shared.registerForRemoteNotifications()
    #elseif canImport(AppKit)
    NSApplication.shared.registerForRemoteNotifications()
    #endif
}
```

## Files Modified
- `/Users/alekdob/Desktop/Dev/Personal/namios-app-temp/Sources/MeowApp.swift` (added MacAppDelegate, lines 57-96; updated App struct, line 104)
- `/Users/alekdob/Desktop/Dev/Personal/namios-app-temp/Sources/Core/Network/PushNotificationManager.swift` (platform-specific registration, lines 78-83)

## Key Insight
**Multi-platform delegate lifecycle**: iOS uses `UIApplicationDelegate`, macOS uses `NSApplicationDelegate`. SwiftUI provides `@UIApplicationDelegateAdaptor` and `@NSApplicationDelegateAdaptor` — use `#if os(iOS)` / `#elseif os(macOS)` to attach the right one. Without a macOS delegate, system callbacks (especially push notification registration) are never delivered.

**Race condition pattern**: If a callback can fire before an optional is assigned, use `didSet` observer to flush any pending data. This is especially important for APNs tokens on iOS because the system may deliver the token immediately if the app already has user permission from a previous run.

## Affected Platforms
- macOS 14+
- iOS 17+ (improved push notification reliability)
