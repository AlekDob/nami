---
type: gotcha
project: namios
created: 2026-02-18
last_verified: 2026-02-18
tags: [xcodegen, info-plist, project-yml, build]
---

# xcodegen Regenerates Info.plist — Manual Edits Are Lost

## Trigger
Editing `Sources/Info.plist` directly, then running `xcodegen generate`.

## What Happens
xcodegen overwrites `Info.plist` from the `info.properties` section in `project.yml`. Any manual additions (like `NSServices`) are silently lost.

## Fix
Add all Info.plist entries in `project.yml` under `targets.MeowApp.info.properties`, not in `Info.plist` directly.

```yaml
# project.yml
targets:
  MeowApp:
    info:
      path: Sources/Info.plist
      properties:
        NSServices:
          - NSMessage: translateToEnglish
            NSMenuItem:
              default: "Nami/Translate to English"
            NSSendTypes:
              - NSStringPboardType
            NSReturnTypes:
              - NSStringPboardType
            NSPortName: NamiOS  # Must match CFBundleName, not display name!
```

Then run `xcodegen generate` — the plist is regenerated correctly.

## Also Applies To
- Any custom plist key (URL schemes, entitlements, etc.)
- The project uses `GENERATE_INFOPLIST_FILE: YES` which means xcodegen fully controls plist content

## Prevention
**Rule:** Never edit `Sources/Info.plist` directly in a xcodegen project. Always edit `project.yml` and regenerate.
