# Tasks: MyMind Design System

**Feature**: 002-mymind-design-system
**Generated**: 2026-02-28

## Task List

### TASK-001: Extend MeowTheme with card design tokens
- **Priority**: P1
- **Depends on**: —
- **File**: `Sources/Core/Design/MeowTheme.swift`
- **Action**: Add `Cards` enum (cornerRadius, shadow params, backgrounds) and `Gradients` enum (domain-specific gradient palettes: session, job, command, creation, soul, setting). Each palette has 3 color pair variants for visual variety.
- **Acceptance**: `MeowTheme.Cards.cornerRadius`, `MeowTheme.Gradients.session` etc. compile and are accessible from any view.

### TASK-002: Create NamiCardStyle ViewModifier
- **Priority**: P1
- **Depends on**: TASK-001
- **File**: `Sources/Core/Design/NamiCardStyle.swift` (NEW)
- **Action**: ViewModifier that applies: `MeowTheme.Cards.backgroundDark/Light` adaptive background, `cornerRadius(16, style: .continuous)`, soft shadow (adaptive dark/light opacity). Usage: `.modifier(NamiCardStyle())`.
- **Acceptance**: A plain `Text("Hello")` wrapped in `.modifier(NamiCardStyle())` renders as a floating card with rounded corners and shadow.

### TASK-003: Create NamiEmptyState reusable view
- **Priority**: P1
- **Depends on**: TASK-001
- **File**: `Sources/Core/Design/NamiEmptyState.swift` (NEW)
- **Action**: View with params: `icon: String`, `title: String`, `subtitle: String`, `actionLabel: String?`, `action: (() -> Void)?`. Uses warm styling: large icon in `.tertiary`, semibold title, secondary subtitle, optional `.borderedProminent` button with accent tint.
- **Acceptance**: All 5 empty states across the app can be replaced with `NamiEmptyState(...)`.

### TASK-004: Create GradientAccentBar view
- **Priority**: P1
- **Depends on**: TASK-001
- **File**: `Sources/Core/Design/GradientAccentBar.swift` (NEW)
- **Action**: Simple view: `LinearGradient` with 4px height, takes `colors: [Color]`. Used at the top of cards for the MyMind accent bar effect.
- **Acceptance**: `GradientAccentBar(colors: MeowTheme.Gradients.session[0])` renders a thin gradient bar.

### TASK-005: Redesign SessionListView
- **Priority**: P1
- **Depends on**: TASK-002, TASK-003, TASK-004
- **File**: `Sources/Features/Chat/SessionListView.swift`
- **Action**: Replace `List` with `ScrollView` + `LazyVStack(spacing: 12)`. Each session = full-width card with: `GradientAccentBar` at top, session title (15pt semibold), preview snippet (12pt secondary, 2 lines), relative date (11pt muted). Card uses `NamiCardStyle`. Swipe-to-delete via `.swipeActions`. Empty state uses `NamiEmptyState`. Selected session has subtle border highlight. Keep `NavigationStack`, toolbar, `.refreshable`.
- **Acceptance**: Sessions render as floating cards, no List chrome visible. Swipe-to-delete works. Empty state is warm. Pull-to-refresh works.

### TASK-006: Redesign JobsListView
- **Priority**: P1
- **Depends on**: TASK-002, TASK-003, TASK-004
- **File**: `Sources/Features/Jobs/JobsListView.swift`
- **Action**: Replace `List` with `ScrollView` + `LazyVStack(spacing: 12)`. Each job = card with: `GradientAccentBar` (blue palette), job name, task preview, cron badge as styled capsule, toggle. Disabled jobs show dimmed card (opacity 0.6). Swipe-to-delete preserved. Empty state uses `NamiEmptyState`.
- **Acceptance**: Jobs render as floating cards with blue accents. Toggle, swipe-delete, create sheet all functional.

### TASK-007: Redesign ChatBubble
- **Priority**: P2
- **Depends on**: TASK-001
- **File**: `Sources/Core/Design/ChatBubble.swift`
- **Action**: User messages: warm gradient background (from MeowTheme.Gradients) instead of flat `surfaceColor`, soft shadow, white text. Assistant messages: `NamiCardStyle` card with generous line spacing (6pt on iOS, 5pt on macOS), soft shadow. Action row (copy, TTS, stats) remains below with same styling.
- **Acceptance**: User messages pop with warm gradient backgrounds. Assistant messages float as soft cards. All actions (copy, TTS) still work.

### TASK-008: Warm up ChatView input bar
- **Priority**: P2
- **Depends on**: TASK-001
- **File**: `Sources/Features/Chat/ChatView.swift`
- **Action**: Input pill: warm surface background with subtle inner glow. Send button: use `MeowTheme.orange` (warm accent) when active instead of `primaryColor`. Corner radius slightly larger (24). Plus button matches warm styling.
- **Acceptance**: Input bar feels warm and inviting. Send button uses orange accent when message is ready.

### TASK-009: Redesign SoulView
- **Priority**: P2
- **Depends on**: TASK-002, TASK-003
- **File**: `Sources/Features/Soul/SoulView.swift`
- **Action**: Replace `List` with `ScrollView`. Nami entity hero at top (160px, centered). Below: visual panels as cards using `NamiCardStyle`. Personality = selectable cards (not Picker dropdown). Form style = selectable visual previews. Colors = gradient swatches (not system ColorPicker). Level progress bar with gradient fill. Personality editor = card with monospace text.
- **Acceptance**: Soul feels like a premium customization screen, not a settings form. Nami preview updates live on every change.

### TASK-010: Redesign AICommandsListView
- **Priority**: P2
- **Depends on**: TASK-002, TASK-003, TASK-004
- **File**: `Sources/Features/AICommands/AICommandsListView.swift`
- **Action**: Replace `List` with `ScrollView` + `LazyVStack(spacing: 10)`. Each command = compact horizontal card with: thin gradient accent bar (purple palette), command icon, name, prompt preview (1 line), shortcut badge (macOS), toggle. Cards use `NamiCardStyle`. Edit opens as sheet (unchanged). Reorder via `onMove` or manual drag.
- **Acceptance**: Commands render as compact floating cards. Toggle, edit sheet, reorder all functional.

### TASK-011: Redesign OSView as masonry gallery
- **Priority**: P2
- **Depends on**: TASK-002, TASK-003
- **File**: `Sources/Features/OS/OSView.swift`
- **Action**: Replace sectioned `List` with `LazyVGrid(columns: 2)` masonry grid (same pattern as BrainView). Each creation = card with type-specific gradient header (apps=blue, docs=green, scripts=orange), creation name, timestamp. Variable card height based on content hash for masonry feel.
- **Acceptance**: OS tab looks like a portfolio gallery. Type gradients distinguish apps/docs/scripts visually.

### TASK-012: Style SettingsView sections as cards
- **Priority**: P3
- **Depends on**: TASK-001
- **File**: `Sources/Features/Settings/SettingsView.swift`
- **Action**: Keep `List` structure but: custom `listRowBackground` with rounded corners. Connection status at top = prominent card with green/red gradient accent. Section headers styled with icons. Banner overlays kept as-is (already use `.ultraThinMaterial`).
- **Acceptance**: Settings feels warmer while maintaining Form usability. Connection status card is visually prominent.

### TASK-013: Redesign ModelPickerView as preset cards
- **Priority**: P3
- **Depends on**: TASK-002
- **File**: `Sources/Features/Settings/ModelPickerView.swift`
- **Action**: Three large selectable cards for fast/smart/pro presets. Each card: gradient background (fast=green, smart=blue, pro=purple), preset name, model description, capability badges (vision pill, tools pill). Selected card has highlighted border with subtle glow.
- **Acceptance**: Model selection is visual and clear. Capabilities are immediately visible as badge pills.

### TASK-014: Run xcodegen and verify builds
- **Priority**: P1
- **Depends on**: all above
- **File**: `project.yml`
- **Action**: Run `/opt/homebrew/bin/xcodegen generate`. Build for iOS simulator and macOS. Fix any compilation errors. Verify no layout warnings on macOS.
- **Acceptance**: Both iOS and macOS targets build clean with zero warnings.

### TASK-015: Write diary entry
- **Priority**: P3
- **Depends on**: TASK-014
- **File**: `documentation/diary/2026-02-28.md`
- **Action**: Append implementation summary to diary.
- **Acceptance**: Diary entry documents the MyMind design system implementation.

## Dependency Graph

```
TASK-001 (MeowTheme tokens)
  ├── TASK-002 (NamiCardStyle) ──┐
  ├── TASK-003 (NamiEmptyState) ─┤
  ├── TASK-004 (GradientAccentBar)┤
  │                               │
  │   ┌───────────────────────────┘
  │   │
  │   ├── TASK-005 (SessionListView) ─── P1
  │   ├── TASK-006 (JobsListView) ────── P1
  │   ├── TASK-009 (SoulView) ────────── P2
  │   ├── TASK-010 (AICommandsListView)─ P2
  │   ├── TASK-011 (OSView) ──────────── P2
  │   └── TASK-013 (ModelPickerView) ─── P3
  │
  ├── TASK-007 (ChatBubble) ──────────── P2
  ├── TASK-008 (ChatView input) ──────── P2
  └── TASK-012 (SettingsView) ────────── P3

All above ──► TASK-014 (xcodegen + build)
           ──► TASK-015 (diary)
```

## Parallelization

These tasks can be done in parallel:
- TASK-002 + TASK-003 + TASK-004 (all depend only on TASK-001)
- TASK-005 + TASK-006 (independent views, same dependency set)
- TASK-007 + TASK-008 (chat area, both depend only on TASK-001)
- TASK-009 + TASK-010 + TASK-011 (independent views)
- TASK-012 + TASK-013 (independent views)
