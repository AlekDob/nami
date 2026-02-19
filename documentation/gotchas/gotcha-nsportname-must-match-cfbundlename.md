---
type: gotcha
project: namios
created: 2026-02-18
last_verified: 2026-02-18
tags: [macos, services, nsportname, cfbundlename, info-plist]
---

# NSPortName Must Match CFBundleName (Not Display Name)

## Trigger
Declaring `NSServices` in Info.plist with an `NSPortName` that doesn't match the actual `CFBundleName` or `CFBundleExecutable` of the built app.

## What Happens
macOS uses `NSPortName` to find which app should handle a service invocation. If the value doesn't match the bundle name of the running app, macOS silently fails to route the service — no error, no crash, just services that appear in PBS but never work.

## The Trap
In NamiOS, the display name is "Nami" (`CFBundleDisplayName: Nami`) but the actual bundle name and executable are "NamiOS" (`PRODUCT_NAME: NamiOS` in project.yml). Setting `NSPortName: Nami` causes silent failure.

## Fix
Always check what your actual `CFBundleName` is in the built app:

```bash
/usr/libexec/PlistBuddy -c "Print :CFBundleName" /path/to/App.app/Contents/Info.plist
```

Then use that exact value for `NSPortName`:

```yaml
# project.yml — CORRECT
NSPortName: NamiOS  # matches CFBundleName

# project.yml — WRONG (display name, not bundle name)
NSPortName: Nami
```

## Key Distinction
| Property | Value | Purpose |
|----------|-------|---------|
| `CFBundleDisplayName` | Nami | What users see in Finder/Dock |
| `CFBundleName` | NamiOS | Internal name macOS uses for service routing |
| `PRODUCT_NAME` | NamiOS | Xcode build setting → becomes CFBundleName |
| `NSPortName` | **Must match CFBundleName** | How PBS routes service calls |

## Prevention
When setting up NSServices, always verify `NSPortName` against the built app's `CFBundleName`, not the display name.
