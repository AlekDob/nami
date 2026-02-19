---
type: pattern
project: namios
date: 2026-02-09
tags: [race-condition, push-notifications, iOS, macOS, AppDelegate]
---

# Pattern: iOS Push Notification Race Condition (Pending Token Queue)

## Problem
On iOS, APNs device token callback `didRegisterForRemoteNotificationsWithDeviceToken` can arrive **before** `appDelegate.pushManager` is assigned. This happens when:
- App already has push permission from a previous run
- System delivers token immediately on launch
- `pushManager` not yet initialized

Result: Token is silently lost via optional chaining `pushManager?.handleDeviceToken()`, push notifications never work.

## Solution: Pending Token Queue Pattern

Use `didSet` observer on the `pushManager` property to flush any queued token:

```swift
final class AppDelegate: NSObject, UIApplicationDelegate {
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

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            if let pm = pushManager {
                // pushManager already assigned, deliver immediately
                pm.handleDeviceToken(deviceToken)
            } else {
                // pushManager not yet assigned, queue the token
                print("[AppDelegate] token arrived before pushManager — queuing")
                pendingToken = deviceToken
            }
        }
    }
}
```

## How It Works

1. **Fast path** (pushManager already assigned):
   - Token callback fires
   - `pushManager` exists
   - Token delivered immediately

2. **Slow path** (pushManager not assigned yet):
   - Token callback fires
   - `pushManager` is `nil`
   - Token stored in `pendingToken`
   - Later, when `pushManager` is assigned (via property setter)
   - `didSet` observer detects `pendingToken` is not nil
   - `didSet` delivers the queued token to newly-assigned `pushManager`
   - Clears `pendingToken` to mark delivered

## Key Insight
**Property `didSet` observers fire AFTER the property is set**, making them ideal for "post-assignment initialization" patterns. This is perfect for handling race conditions where dependent objects arrive out of order.

The pattern works because:
- Token callback stores data in `pendingToken`
- Setting `pushManager` property triggers `didSet`
- `didSet` checks if pending data exists and delivers it
- No token is ever lost

## Variants

### macOS (NSApplicationDelegate)
Same pattern, use `NSApplication` and `NSApplicationDelegate`:

```swift
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

    func application(
        _ application: NSApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Task { @MainActor in
            if let pm = pushManager {
                pm.handleDeviceToken(deviceToken)
            } else {
                pendingToken = deviceToken
            }
        }
    }
}
```

## Affected Code
- `AppDelegate` initialization in app launch
- `pushManager` assignment (usually in SceneDelegate or main App view setup)

## Platforms
- iOS 17+
- macOS 14+
