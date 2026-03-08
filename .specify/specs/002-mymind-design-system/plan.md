# Implementation Plan: MyMind Design System

**Feature**: 002-mymind-design-system
**Created**: 2026-02-28
**Approach**: Bottom-up — design tokens first, then shared components, then view-by-view conversion

## Architecture Overview

### Current State
- 8 views use `List` with `.insetGrouped` (SessionList, Jobs, AICommands, Settings, Soul, OS, ModelPicker, MemoryBrowser)
- 1 view already uses MyMind language (BrainView + BrainCard + BrainDetailView)
- ChatView uses custom LazyVStack but with plain ChatBubble styling
- `MeowTheme` has Dark/Light colors, spacing, corners — but NO card tokens, NO gradient palettes
- Each view duplicates color helper computed properties (`bgColor`, `primaryColor`, etc.)

### Target State
- All views use card-based layouts with gradient accents
- `MeowTheme` extended with `Cards` namespace (gradients, shadows, card backgrounds)
- `NamiCardStyle` ViewModifier encapsulates standard card appearance
- `NamiEmptyState` reusable component for warm empty states
- ChatBubble redesigned with soft shadows and warm typography
- Settings keeps Form layout but with card-styled sections

## Design Tokens to Add to MeowTheme

```swift
extension MeowTheme {
    enum Cards {
        static let cornerRadius: CGFloat = 16
        static let shadowRadius: CGFloat = 8
        static let shadowY: CGFloat = 4
        static let shadowOpacityDark: Double = 0.3
        static let shadowOpacityLight: Double = 0.08
        static let backgroundDark = Color(hex: 0x1A1A1A)
        static let backgroundLight = Color.white
    }

    // Domain-specific gradient palettes
    enum Gradients {
        static let session: [[Color]]    // warm amber/orange
        static let job: [[Color]]        // cool blue/indigo
        static let command: [[Color]]    // purple/violet
        static let creation: [[Color]]   // green/teal
        static let soul: [[Color]]       // pink/rose
        static let setting: [[Color]]    // gray/slate
    }
}
```

## Shared Components

### 1. NamiCardStyle (ViewModifier)
Encapsulates: background, cornerRadius(16), soft shadow, adaptive dark/light.
Applied via `.modifier(NamiCardStyle())`.

### 2. NamiEmptyState (View)
Reusable empty state with: SF Symbol icon, title, subtitle, optional action button.
Replaces the 5+ duplicate empty state implementations.

### 3. GradientAccentBar (View)
A thin (4px) horizontal gradient bar at the top of each card.
Color determined by domain + content hash (same pattern as BrainCard).

## Implementation Order

### Phase 1: Foundation (no visual changes yet)
1. **Extend MeowTheme** with `Cards` and `Gradients` namespaces
2. **Create NamiCardStyle** ViewModifier in `Sources/Core/Design/`
3. **Create NamiEmptyState** reusable view in `Sources/Core/Design/`
4. **Create GradientAccentBar** in `Sources/Core/Design/`

### Phase 2: High-Impact Views (P1)
5. **SessionListView** → Replace `List` with `ScrollView` + `LazyVStack`. Each session = full-width card with gradient accent bar, title, preview snippet, relative date. Swipe-to-delete via `.swipeActions`. Keep `NavigationStack`.
6. **JobsListView** → Same pattern. Card per job with blue gradient accent, cron badge as styled pill, toggle on card. Swipe-to-delete preserved.

### Phase 3: Chat Redesign (P2)
7. **ChatBubble** → User messages: accent gradient background (not plain surface), rounded card with soft shadow. Assistant messages: surface card with soft shadow, generous line spacing. Action row stays below.
8. **ChatView inputBar** → Warmer input background, slightly larger corner radius, warm accent on send button when active.

### Phase 4: Secondary Views (P2)
9. **SoulView** → Remove `List`. Nami entity hero at top (larger, 160px). Visual panels: personality as selectable cards, form style as visual previews, colors as gradient swatches. Level progress bar with gradient fill.
10. **AICommandsListView** → Replace `List` with `ScrollView` + `LazyVStack`. Compact horizontal cards with gradient accent bar, name, prompt preview, shortcut badge (macOS), toggle.
11. **OSView** → Replace sectioned `List` with 2-column `LazyVGrid` masonry (like BrainView). Type-specific gradients.

### Phase 5: Form Views (P3)
12. **SettingsView** → Keep `List` layout but style sections as cards: custom `.listRowBackground` with rounded corners and subtle shadow. Connection status card at top with green/red gradient accent. Use `SettingsCardSection` wrapper.
13. **ModelPickerView** → Three large selectable cards for fast/smart/pro presets. Gradient backgrounds, capability badge pills, glow on selection.

### Phase 6: Cleanup
14. Remove backward compat aliases from MeowTheme that are no longer referenced
15. Run xcodegen, verify iOS + macOS builds
16. Diary entry

## Files Modified

| File | Action | Lines Est. |
|------|--------|-----------|
| `Core/Design/MeowTheme.swift` | Edit — add Cards, Gradients | +40 |
| `Core/Design/NamiCardStyle.swift` | **New** — ViewModifier | ~30 |
| `Core/Design/NamiEmptyState.swift` | **New** — reusable empty state | ~40 |
| `Core/Design/GradientAccentBar.swift` | **New** — gradient bar | ~25 |
| `Features/Chat/SessionListView.swift` | Rewrite — cards layout | ~150 |
| `Features/Jobs/JobsListView.swift` | Rewrite — cards layout | ~160 |
| `Core/Design/ChatBubble.swift` | Edit — warm styling | ~190 |
| `Features/Chat/ChatView.swift` | Edit — input bar warm | ~380 (minor edits) |
| `Features/Soul/SoulView.swift` | Rewrite — visual panels | ~230 |
| `Features/AICommands/AICommandsListView.swift` | Rewrite — compact cards | ~200 |
| `Features/OS/OSView.swift` | Rewrite — masonry grid | ~150 |
| `Features/Settings/SettingsView.swift` | Edit — card-styled sections | ~370 (moderate edits) |
| `Features/Settings/ModelPickerView.swift` | Rewrite — preset cards | ~120 |

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| macOS layout loops with new card layouts | Use `LazyVStack` not `VStack`, avoid `NSTextView`, test on macOS after each view |
| Swipe-to-delete doesn't work outside `List` | Use `.swipeActions` on card views or custom `DragGesture` |
| Settings Form breaks with custom styling | Keep `List` structure, only modify `listRowBackground` and section headers |
| Too many files for one PR | Implement in phases, each phase is independently shippable |
| Dynamic Type breaks card layouts | Cards use `.lineLimit` + dynamic padding, test with large text |

## Decision Log

- **Sessions = vertical cards (not grid)**: User chose full-width for readability
- **Settings = Form with card styling**: User chose practicality over pure MyMind
- **Chat = redesign**: User explicitly requested warm visual treatment for messages
- **No third-party deps**: Constitution mandate, pure SwiftUI
