---
type: gotcha
project: namios
created: 2026-02-18
last_verified: 2026-02-18
tags: [macos, services, pbs, pasteboard-server, applications, xcode, deriveddata]
---

# macOS PBS Only Discovers Services from /Applications

## Trigger
Building and running a macOS app from Xcode that declares `NSServices` in Info.plist. The services do not appear in the right-click → Services menu.

## What Happens
macOS PBS (Pasteboard Server) indexes `NSServices` only from apps in **registered locations** like `/Applications` or `~/Applications`. Apps running from Xcode's DerivedData path (`~/Library/Developer/Xcode/DerivedData/...`) are **not indexed** by PBS for service discovery.

`pbs -dump_pboard` may show the services if you manually register with `lsregister`, but the right-click menu still won't show them until the app bundle is in a standard location.

## Fix
After building in Xcode, copy the built app to `/Applications`:

```bash
# One-liner: copy latest build to /Applications
cp -R "$(xcodebuild -showBuildSettings -scheme MeowApp_macOS 2>/dev/null | grep -m1 BUILT_PRODUCTS_DIR | awk '{print $3}')/NamiOS.app" /Applications/NamiOS.app
```

Then flush PBS and register with LaunchServices:

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister /Applications/NamiOS.app
/System/Library/CoreServices/pbs -flush
```

## Also Important
- **Services are NOT auto-enabled.** Even after PBS discovers them, the user must manually enable each service checkbox in **System Settings → Keyboard → Keyboard Shortcuts → Services**.
- This is a macOS security restriction — cannot be bypassed programmatically.
- Once enabled, services persist across app updates (same bundle ID).

## Verification
```bash
# Check if PBS sees the services
/System/Library/CoreServices/pbs -dump_pboard 2>&1 | grep -i "nami"
```

## Automation Option
Add a post-build script in Xcode (Build Phases → Run Script) to auto-copy:
```bash
if [ "$CONFIGURATION" = "Debug" ]; then
    cp -R "${BUILT_PRODUCTS_DIR}/${PRODUCT_NAME}.app" "/Applications/${PRODUCT_NAME}.app"
fi
```
