# APNs Push Notifications - Test & Documentation Guide

This document serves two purposes:
1. **Documentation**: Explains how push notifications work in NamiOS (some Swift filenames still use legacy "MeowApp" naming)
2. **Manual Test Plan**: Step-by-step verification on a physical iPhone

---

## How Push Notifications Work

MeowApp uses Apple Push Notification service (APNs) to deliver real-time alerts when the app is not in the foreground. When the backend (Bun server on Hetzner) generates a response -- either from a chat message or a scheduled task -- it sends an HTTP/2 request to Apple's APNs servers, which then deliver the notification to the user's iPhone.

The system uses token-based authentication with a `.p8` key (ES256 JWT), meaning the key never expires and works across all apps under the same team. Device tokens are stored server-side in a simple JSON file and automatically cleaned up when Apple reports them as stale.

### Architecture

```
                    BACKEND (Hetzner, port 3000)
                    +--------------------------+
                    |  src/cli/index.ts        |
                    |    |                     |
                    |    +-- Scheduler fires   |
                    |    |   onNotify/onTrigger |
                    |    |                     |
                    |    +-- WebSocket handler  |
                    |        (chat response)    |
                    |    |                     |
                    |    v                     |
                    |  src/channels/apns.ts    |
                    |    |                     |
                    |    +-- JWT (ES256, .p8)  |
                    |    +-- HTTP/2 POST       |
                    |    +-- data/devices.json |
                    +-----------+--------------+
                                |
                                v
                    +------------------------+
                    |   Apple APNs Servers   |
                    | api.sandbox.push.apple |
                    +----------+-------------+
                               |
                               v
                    +------------------------+
                    |    iPhone (MeowApp)    |
                    |                        |
                    |  AppDelegate           |
                    |    -> device token     |
                    |    -> POST /register   |
                    |                        |
                    |  PushNotificationMgr   |
                    |    -> permissions      |
                    |    -> foreground gate  |
                    |                        |
                    |  [Background] = banner |
                    |  [Foreground] = in-chat|
                    +------------------------+
```

### Key Concepts

**Device Token Registration**: On first launch, the app requests notification permission. If granted, iOS provides a unique device token. The app sends this token to the backend via `POST /api/register-device`. The backend stores it in `data/devices.json`.

**Foreground Suppression**: When the app is in the foreground, `UNUserNotificationCenterDelegate.willPresent` returns `[]` (no presentation options), so no banner appears. The WebSocket handler shows the message in-chat instead. When the app is backgrounded, iOS shows the push notification normally.

**JWT Token Caching**: The backend generates an ES256 JWT signed with the `.p8` key, cached for 50 minutes (Apple allows 1 hour). This avoids re-signing on every push.

**Stale Token Cleanup**: If Apple responds with HTTP 410 (Gone) or 400 (Bad Request), the device token is automatically removed from `devices.json`.

### Notification Triggers

| Event | Title | Body |
|-------|-------|------|
| Chat response (via WebSocket) | `Nami` | First 200 chars of response |
| Scheduled job fires (onNotify) | `Task firing` | `{job.name}: {job.task}` |
| Scheduled job completes (onTrigger) | `Task: {job.name}` | First 200 chars of result |

### Where Things Live

| File | What it does |
|------|-------------|
| **Backend** | |
| `src/channels/apns.ts` | APNs HTTP/2 client, JWT generation, device storage |
| `src/api/routes.ts` | `POST/DELETE /api/register-device` endpoints |
| `src/api/websocket.ts` | Sends push after every chat response |
| `src/cli/index.ts` | Inits APNs, wires scheduler notifications |
| `data/devices.json` | Persisted device tokens |
| `data/apns/AuthKey_XXXX.p8` | Apple private key (DO NOT COMMIT) |
| **iOS** | |
| `PushNotificationManager.swift` | Permission request, token handling, foreground delegate |
| `MeowApp.swift` | AppDelegate adapter for device token callbacks |
| `MeowAPIClient.swift` | `registerDevice(token:)` / `unregisterDevice(token:)` |
| `APITypes.swift` | `RegisterDeviceRequest` / `RegisterDeviceResponse` |
| `MeowApp.entitlements` | `aps-environment: development` |

### Server Environment Variables

```
APNS_KEY_PATH=/root/meow/data/apns/AuthKey_XXXXXXXX.p8
APNS_KEY_ID=XXXXXXXX           # from Apple Developer > Keys
APNS_TEAM_ID=FC38UVV3V3        # from Apple Developer > Membership
APNS_BUNDLE_ID=com.alekdob.MeowApp
APNS_PRODUCTION=false           # true for App Store builds
```

---

## Pre-Test Setup Checklist

Before running any tests, complete these one-time setup steps:

- [ ] Created APNs Key in Apple Developer Portal (Keys > + > APNs)
- [ ] Downloaded `.p8` file and noted Key ID
- [ ] Uploaded `.p8` to server: `scp AuthKey_XXXX.p8 root@ubuntu-4gb-hel1-1:/root/meow/data/apns/`
- [ ] Added env vars to server `.env` (see above)
- [ ] Restarted meow service: `ssh root@ubuntu-4gb-hel1-1 "systemctl restart meow"`
- [ ] In Xcode: target MeowApp_iOS > Signing & Capabilities > + Capability > Push Notifications
- [ ] Selected your Team in Signing settings
- [ ] Have a **physical iPhone** connected (push does NOT work on Simulator)

---

## Manual Testing on iPhone

Build and run MeowApp on a physical iPhone from Xcode, then follow each test.

---

### Test 1: Permission Request on First Launch

**What to check**: The app asks for notification permission on first launch.

1. Delete MeowApp from your iPhone (clean install)
2. Build and run from Xcode
3. Configure server URL and API key in Settings
4. Return to Chat tab
5. Wait for the app to finish loading

**Pass criteria**:
- [ ] iOS shows a system alert: "MeowApp Would Like to Send You Notifications"
- [ ] Tapping "Allow" dismisses the alert
- [ ] No crash occurs

**If it doesn't work**: Check that the Push Notifications capability is added in Xcode > Signing & Capabilities. Also verify the entitlements file is linked in Build Settings.

---

### Test 2: Device Token Registration

**What to check**: After granting permission, the app registers its device token with the server.

1. Allow notifications (from Test 1)
2. SSH into the server:
   ```
   ssh root@ubuntu-4gb-hel1-1 "cat /root/meow/data/devices.json"
   ```

**Pass criteria**:
- [ ] `devices.json` exists and contains at least one entry
- [ ] The entry has a `token` field (64+ character hex string)
- [ ] The entry has a `registeredAt` ISO timestamp
- [ ] Running the app again does NOT create a duplicate entry

**If it doesn't work**: Check server logs: `ssh root@ubuntu-4gb-hel1-1 "journalctl -u meow --since '5 min ago'"`. Look for APNs initialization messages. Verify the API key is correct in the iOS Settings screen.

---

### Test 3: Push Notification from Chat (App Backgrounded)

**What to check**: When someone sends a message to Nami and the app is in the background, a push notification appears.

1. Open MeowApp and verify it's connected (Chat tab, no errors)
2. Press the Home button or swipe up to background the app
3. From a terminal, send a chat message via the API:
   ```
   curl -X POST http://<SERVER_IP>:3000/api/chat \
     -H "Authorization: Bearer <MEOW_API_KEY>" \
     -H "Content-Type: application/json" \
     -d '{"messages":[{"role":"user","content":"say hello in 5 words"}]}'
   ```
4. Wait for the response (may take a few seconds)

**Pass criteria**:
- [ ] A push notification banner appears on the lock screen / notification center
- [ ] The notification title is "Nami"
- [ ] The notification body contains the first ~200 characters of the response
- [ ] The notification plays the default sound
- [ ] Tapping the notification opens MeowApp

**If it doesn't work**:
- Check APNs init: `ssh root@ubuntu-4gb-hel1-1 "journalctl -u meow | grep APNs"`
- Check devices exist: `cat /root/meow/data/devices.json`
- Verify `APNS_PRODUCTION=false` for sandbox (development builds)
- Make sure iPhone notifications are not silenced (Focus mode off)

---

### Test 4: No Banner When App is in Foreground

**What to check**: When the app is actively open, no push banner should appear. The message shows in-chat via WebSocket instead.

1. Open MeowApp to the Chat tab
2. Keep the app in the foreground
3. From another device/terminal, trigger a scheduled job or send a chat via API (same curl as Test 3)
4. Observe the app

**Pass criteria**:
- [ ] No push notification banner appears
- [ ] The response appears in the chat view normally
- [ ] No duplicate messages (one in chat + one from push)

---

### Test 5: Scheduled Job Push Notification

**What to check**: When a scheduled job fires, a push notification is sent.

1. Create a test job that fires in 1 minute:
   ```
   curl -X POST http://<SERVER_IP>:3000/api/jobs \
     -H "Authorization: Bearer <MEOW_API_KEY>" \
     -H "Content-Type: application/json" \
     -d '{"name":"test-push","cron":"in 1m","task":"say hello","notify":true}'
   ```
2. Background MeowApp on iPhone
3. Wait ~1 minute

**Pass criteria**:
- [ ] A push notification appears: title "Task firing", body contains "test-push"
- [ ] Shortly after, a second push appears: title "Task: test-push", body contains the agent's response
- [ ] Both notifications have sound

4. Clean up:
   ```
   curl -X DELETE http://<SERVER_IP>:3000/api/jobs/test-push \
     -H "Authorization: Bearer <MEOW_API_KEY>"
   ```

---

### Test 6: Permission Denied Flow

**What to check**: If the user denies notification permission, the app still works without crashing.

1. Delete MeowApp (clean install)
2. Build and run
3. When the notification permission alert appears, tap "Don't Allow"
4. Configure server URL and API key
5. Send a chat message from within the app

**Pass criteria**:
- [ ] No crash
- [ ] Chat works normally via REST/WebSocket
- [ ] No push notifications are received (as expected)
- [ ] No device token is registered on the server (check `devices.json`)

---

### Test 7: App Kill and Relaunch

**What to check**: After force-quitting and relaunching, push notifications still work.

1. With MeowApp running and notifications working (from Test 3)
2. Force-quit MeowApp (swipe up from app switcher)
3. Wait 30 seconds
4. Send a chat via API (same curl as Test 3)
5. Observe

**Pass criteria**:
- [ ] Push notification still arrives (Apple delivers to the device, not the app)
- [ ] Tapping the notification launches MeowApp
- [ ] After reopening, the chat view is functional

**Note**: Push notifications are delivered by iOS to the device, not to the app process. They work even when the app is fully killed. The only case where they don't work is if the user has disabled notifications in iOS Settings.

---

### Test 8: Multiple Devices

**What to check**: If you run MeowApp on two devices, both receive push notifications.

1. Install and configure MeowApp on a second device (iPad or another iPhone)
2. Allow notifications on both
3. Check `devices.json` on the server:
   ```
   ssh root@ubuntu-4gb-hel1-1 "cat /root/meow/data/devices.json"
   ```
4. Send a chat via API
5. Background both apps

**Pass criteria**:
- [ ] `devices.json` shows two device entries with different tokens
- [ ] Both devices receive the push notification

---

## Troubleshooting

### "APNs initialized" not showing in server logs

- Check that `APNS_KEY_PATH` points to the correct `.p8` file
- Verify the file exists: `ls -la /root/meow/data/apns/`
- Check file permissions: `chmod 600 /root/meow/data/apns/*.p8`

### Push notifications work once then stop

- The device token may have changed (reinstall, iOS update). Delete `devices.json` and relaunch the app
- JWT may have expired unexpectedly. Restart the service to force token regeneration

### "BadDeviceToken" in server logs

- You're likely using a production token with the sandbox endpoint (or vice versa)
- Development builds (Xcode) use `api.sandbox.push.apple.com` (`APNS_PRODUCTION=false`)
- TestFlight/App Store builds use `api.push.apple.com` (`APNS_PRODUCTION=true`)
- Device tokens are different between sandbox and production -- they are NOT interchangeable

### App crashes on launch after adding push

- Verify the entitlements file is correctly linked in Build Settings > CODE_SIGN_ENTITLEMENTS
- Make sure the Push Notifications capability is added in Signing & Capabilities
- Check that the provisioning profile includes push notification entitlements

### No permission alert appears

- You may have already responded to the alert (iOS only asks once)
- Go to iPhone Settings > MeowApp > Notifications to check/change permission
- To reset: delete the app, wait a few minutes, reinstall

---

## Architecture Summary

### Before (WebSocket Only)

```
Server  --[WebSocket]--> iOS App (must be running)
        --[Discord DM]--> Discord (always)
```

Notifications only worked if the app had an active WebSocket connection. No way to reach the user when the app was backgrounded or killed.

### After (WebSocket + APNs)

```
Server  --[WebSocket]--> iOS App (foreground = in-chat)
        --[APNs HTTP/2]--> Apple --> iPhone (background = banner)
        --[Discord DM]--> Discord (always)
```

All three channels fire simultaneously. The iOS app suppresses banners when in foreground to avoid duplicates.

### Key Design Decisions

1. **Always send APNs, let iOS deduplicate**: Simpler than tracking WebSocket connection state server-side. `willPresent` returns `[]` when foreground.
2. **JSON file for device tokens**: Only 1-3 devices for a personal assistant. SQLite would be overkill.
3. **`.p8` key (not `.p12` certificate)**: Never expires, works across all apps, single key for the whole team.
4. **No third-party push library**: Uses `node:http2` directly on Bun. Zero additional dependencies.
