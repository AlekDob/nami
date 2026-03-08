---
type: gotcha
project: namios
created: 2026-03-05
last_verified: 2026-03-05
tags: [macos, nsvisualeffectview, light-mode, hud, appearance]
---
# NSVisualEffectView .hudWindow ignores SwiftUI dark scheme in light mode

## Trigger
Floating NSPanel with `NSVisualEffectView(material: .hudWindow)` + SwiftUI content forced to dark via `.preferredColorScheme(.dark)` / `.environment(\.colorScheme, .dark)`.

## Problem
- `.preferredColorScheme(.dark)` and `.environment(\.colorScheme, .dark)` only affect the SwiftUI view hierarchy
- The underlying `NSVisualEffectView` is AppKit — it follows the **system** appearance
- In light mode: HUD material renders as **light blur**, but SwiftUI text is white → invisible text
- In dark mode: everything looks fine (HUD dark + white text)

## Fix
Force the AppKit layer to dark independently:

```swift
let visualEffect = NSVisualEffectView()
visualEffect.material = .hudWindow
visualEffect.appearance = NSAppearance(named: .darkAqua) // <- THIS
```

## Rule
When mixing AppKit `NSVisualEffectView` with SwiftUI hosted content, BOTH layers need their appearance set:
1. **AppKit**: `visualEffect.appearance = NSAppearance(named: .darkAqua)`
2. **SwiftUI**: `.preferredColorScheme(.dark)` + `.environment(\.colorScheme, .dark)`

Neither alone is sufficient.

## Affected files
- `Sources/Core/QuickInput/ResultPanel.swift`
- `Sources/Core/QuickInput/ServicePickerPanel.swift`
- `Sources/Core/QuickInput/QuickInputPanel.swift`
