# Feature Specification: MyMind Design System

**Feature Branch**: `002-mymind-design-system`
**Created**: 2026-02-28
**Status**: Clarified
**Input**: User description: "Design system redesign for NamiOS app - MyMind-inspired visual language across the entire app"

## Vision

Transform NamiOS from a utilitarian settings-style UI (`.insetGrouped` Lists everywhere) into a warm, visual, content-first experience inspired by MyMind. Cards replace lists, gradients replace plain rows, search becomes prominent, chrome disappears.

**Reference**: MyMind — visual bookmarking app with masonry grids, colored accent bars, generous whitespace, and zero UI chrome.

**Already done**: BrainView, BrainCard, BrainDetailView (knowledge tab) follow this language. This spec extends it to the remaining 8 List-based views.

### Clarification Decisions (2026-02-28)

1. **Sessions**: Card verticali full-width (una colonna, stile WhatsApp ma con gradient accent bar). NO griglia 2 colonne.
2. **Settings/Forms**: Form con stile card — le sezioni Form diventano card con bordi arrotondati e ombre, ma il layout resta Form-based per praticità con input fields.
3. **ChatView**: RIDISEGNARE anche la chat con il linguaggio MyMind — card con ombre, accent colorati, tipografia generosa. Non lasciare com'è.

---

## User Scenarios & Testing

### User Story 1 - Session List as Visual Cards (Priority: P1)

The user opens the Chat tab or sidebar and sees their conversation history as visual cards instead of a plain list. Each card shows a gradient accent (based on session content or recency), the session title, a preview snippet, and a relative timestamp. The most recent session is visually prominent.

**Why this priority**: Sessions are the most-used view after Chat itself. Converting this to cards has the highest visual impact and sets the pattern for all other views.

**Independent Test**: Open the app, tap the sessions icon. Cards render in a scrollable grid with gradient accents, soft shadows, and no visible List chrome. Swipe-to-delete still works. Tapping a card loads the session.

**Acceptance Scenarios**:

1. **Given** the user has 5+ sessions, **When** they open the session list, **Then** sessions appear as cards in a vertical list with gradient accent bars on the left edge, title, preview snippet, and relative date
2. **Given** the user swipes left on a session card, **When** the swipe completes, **Then** the card shows a red delete action and the session is removed on confirm
3. **Given** the user has zero sessions, **When** they open the session list, **Then** they see a warm empty state with Nami illustration and "Inizia una conversazione" prompt

---

### User Story 2 - Jobs as Visual Cards (Priority: P1)

The user sees their scheduled tasks as visual cards with a gradient accent per job type, toggle switch, cron schedule badge, and next-run countdown. Creating a new job uses a bottom sheet with the same visual language.

**Why this priority**: Jobs are a core feature (cron tasks). Visual cards make the schedule feel alive instead of a boring settings panel.

**Independent Test**: Navigate to Jobs tab. Cards render with gradient accents, enable/disable toggle floats on the card, swipe-to-delete works, "+" button opens create sheet with warm design.

**Acceptance Scenarios**:

1. **Given** the user has 3 jobs, **When** they open the Jobs tab, **Then** each job appears as a card with colored accent, name, task preview, cron badge, and toggle
2. **Given** a job is disabled, **When** viewing the card, **Then** the card appears slightly dimmed with the toggle off
3. **Given** no jobs exist, **When** the user opens the tab, **Then** they see an empty state with "Nessun compito programmato" and a prominent "+" button

---

### User Story 3 - Soul Editor as Visual Panels (Priority: P2)

The user customizes Nami's personality through visual panels instead of form fields. The color picker is a gradient palette, the personality type is selectable cards, and the Nami entity preview updates live at the top.

**Why this priority**: Soul is the emotional heart of the app — it deserves premium visual treatment, but it's used less frequently than Sessions/Jobs.

**Independent Test**: Open Soul tab. Nami entity renders at top, personality options are selectable cards (not a picker), color selection is visual swatches, form style is selectable visual previews. Everything updates the Nami preview live.

**Acceptance Scenarios**:

1. **Given** the user opens Soul, **When** the view loads, **Then** Nami entity renders at the top with current style, and customization options appear as visual panels below
2. **Given** the user taps a personality type card, **When** selected, **Then** the Nami entity updates its animation/expression immediately
3. **Given** the user changes accent color, **When** a swatch is tapped, **Then** the gradient throughout the view updates to reflect the new color

---

### User Story 4 - OS Creations Gallery (Priority: P2)

The user sees their created apps, documents, and scripts as a masonry grid of visual cards (like BrainView), each with a type-specific gradient and icon. Not a sectioned list.

**Why this priority**: OS is a showcase of what Nami created — it should feel like a portfolio gallery, not a file manager.

**Independent Test**: Open OS tab. Cards render in 2-column masonry grid with gradients per type (app=blue, document=green, script=orange). Tapping opens detail.

**Acceptance Scenarios**:

1. **Given** the user has creations across 3 types, **When** they open OS, **Then** all items appear as visual cards in a masonry grid with type-specific gradients
2. **Given** the user taps a creation card, **When** tapped, **Then** a detail view opens with the same gradient header pattern as BrainDetailView
3. **Given** no creations exist, **When** opening OS, **Then** warm empty state: "Nami non ha ancora creato nulla"

---

### User Story 5 - AI Commands as Compact Cards (Priority: P2)

AI Commands appear as horizontal compact cards with colored accent, command name, shortcut badge (macOS), and enable/disable toggle. Editing opens as a styled sheet.

**Why this priority**: Commands are a power-user feature frequently accessed on macOS. Compact cards preserve information density while adding visual warmth.

**Independent Test**: Open AI Commands. Each command is a compact card with accent bar, name, prompt preview, and toggle. macOS shows keyboard shortcut badge.

**Acceptance Scenarios**:

1. **Given** the user has 5 commands, **When** they open AI Commands, **Then** commands appear as compact horizontal cards with colored accents and toggles
2. **Given** a command has a keyboard shortcut (macOS), **When** viewing the card, **Then** a styled capsule badge shows the shortcut
3. **Given** the user taps a card, **When** tapped, **Then** the edit sheet opens with the warm visual language (not `.formStyle(.grouped)`)

---

### User Story 6 - Settings with Visual Sections (Priority: P3)

Settings sections use cards with subtle backgrounds instead of `.insetGrouped` List. The server connection status shows as a visual indicator card at the top. Each section has a gradient header icon.

**Why this priority**: Settings are infrequently used but set the overall impression. Lower priority because functional correctness matters more than visual polish here.

**Independent Test**: Open Settings. Server status is a prominent card at top. Sections are visually separated cards with icons, not plain List sections.

**Acceptance Scenarios**:

1. **Given** the server is connected, **When** opening Settings, **Then** a green-accented status card shows "Connesso" with uptime
2. **Given** the server is disconnected, **When** opening Settings, **Then** a red-accented status card shows "Disconnesso" with retry option
3. **Given** the user scrolls through settings, **When** navigating sections, **Then** each section is a card with rounded corners, soft shadow, and section header icon

---

### User Story 7 - Model Picker as Visual Cards (Priority: P3)

Model presets (fast/smart/pro) appear as large selectable cards with gradient backgrounds, capability badges (vision, tools), and the selected model highlighted with a glow effect.

**Why this priority**: Model selection is occasional but benefits from visual clarity to distinguish capabilities.

**Independent Test**: Open model picker. Three preset cards render with distinct gradients. Model capabilities shown as badge pills. Selection has visual glow.

**Acceptance Scenarios**:

1. **Given** the picker opens, **When** viewing presets, **Then** fast/smart/pro appear as 3 distinct gradient cards with model name, description, and capability badges
2. **Given** the user selects a model, **When** tapped, **Then** the card shows a highlighted border/glow and the selection persists

---

### User Story 8 - Shared Design Tokens (Priority: P1)

All redesigned views use a shared set of design tokens from `MeowTheme` — gradient palettes per content type, card corner radius, shadow definitions, spacing scale, and tag color generator. No hardcoded magic numbers across views.

**Why this priority**: Without shared tokens, each view will diverge visually. This is the foundation that makes everything consistent.

**Independent Test**: Inspect all redesigned views — they all reference `MeowTheme` constants for colors, spacing, corners, and shadows. No hex literals outside the theme.

**Acceptance Scenarios**:

1. **Given** a developer adds a new card view, **When** using `MeowTheme`, **Then** gradient palettes, card styles, and spacing are available as constants
2. **Given** dark mode is active, **When** viewing any card, **Then** backgrounds use `#000000`/`#1A1A1A`, text uses `#FFFFFF`, accents use warm gradients
3. **Given** light mode is active, **When** viewing any card, **Then** backgrounds use white, text uses dark, shadows are subtle

---

### User Story 9 - Chat Messages Redesign (Priority: P2)

Chat messages use the MyMind visual language: user messages as styled cards with soft shadows, assistant messages with generous typography and comfortable line spacing. The input area uses a warm, rounded design with subtle background. Tool use indicators are visual pills instead of plain text.

**Why this priority**: Chat is the most-used view but its current bubble style already works. Redesigning it elevates the whole experience but the existing UX is functional.

**Independent Test**: Open a conversation. Messages render as floating cards with soft shadows, generous padding, and warm typography. Input bar has rounded corners and warm background.

**Acceptance Scenarios**:

1. **Given** a conversation with 5+ messages, **When** viewing the chat, **Then** user messages appear as right-aligned cards with accent gradient, assistant messages as left-aligned cards with surface background, both with soft shadows
2. **Given** the assistant uses a tool, **When** the tool indicator appears, **Then** it renders as a styled pill with tool icon and name (not plain text)
3. **Given** the user types a message, **When** focusing the input, **Then** the input bar has rounded corners, warm background, and generous padding

---

### Edge Cases

- What happens when a view has 100+ items? LazyVGrid/LazyVStack must be used for performance
- What happens on macOS where sidebar splits the view? Cards should fill available width, not stretch infinitely — max width constraint
- What happens when accessibility Dynamic Type is active? Cards must grow vertically, not clip text
- What happens in landscape iPad? Grid columns should increase (3-4 columns instead of 2)

## Requirements

### Functional Requirements

- **FR-001**: All List-based views MUST be replaced with card-based layouts using `LazyVStack` or `LazyVGrid`
- **FR-002**: Every card MUST have a gradient accent (left bar or top area) with colors determined by content type
- **FR-003**: `MeowTheme` MUST be extended with card design tokens: `cardCornerRadius`, `cardShadow`, `cardBackground`, gradient palettes per domain
- **FR-004**: Empty states MUST show warm illustrations with action prompts (not "No data" text)
- **FR-005**: All interactive elements (toggles, buttons, delete actions) MUST remain fully functional after the visual redesign
- **FR-006**: Cards MUST use soft shadows (`color: .black.opacity(0.08/0.3)`, `radius: 8`, `y: 4`) consistent with BrainCard
- **FR-007**: Tag/badge pills MUST use the deterministic `tagColor()` function for consistent coloring
- **FR-008**: All views MUST work on both iOS and macOS with platform-adaptive layouts
- **FR-009**: macOS views MUST NOT use `NSTextView` or trigger layout loops (per constitution VII)
- **FR-010**: No third-party dependencies — pure SwiftUI + Canvas

### Key Entities

- **MeowTheme.Cards**: New namespace for card-specific design tokens (corner radius, shadows, backgrounds, gradients)
- **GradientPalette**: Reusable gradient definitions per content domain (sessions=warm, jobs=blue, creations=green, etc.)
- **CardStyle**: ViewModifier encapsulating the standard card appearance (background, corner radius, shadow)

## Success Criteria

### Measurable Outcomes

- **SC-001**: Zero views use `.insetGrouped` or plain `List` styling after implementation
- **SC-002**: All 8 target views render card-based layouts matching MyMind visual language
- **SC-003**: `MeowTheme` contains all shared tokens — no hardcoded color/spacing values in view files
- **SC-004**: macOS builds with zero layout loop warnings and smooth 60fps scrolling
- **SC-005**: All existing functionality (CRUD, navigation, toggles, delete gestures) works identically after redesign
- **SC-006**: Dark and light modes both look polished (dark-first design, but light must work)
