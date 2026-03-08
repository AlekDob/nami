# NamiOS Constitution

## Core Principles

### I. Native-Only, Zero Dependencies
Every UI component uses pure Apple frameworks (SwiftUI, Canvas, CoreAnimation). No third-party graph libraries, no SPM packages. URLSession for networking, SwiftData for persistence. This keeps the binary small, avoids dependency rot, and ensures forward compatibility with future Apple APIs.

### II. MyMind Design Language
NamiOS follows a visual language inspired by MyMind — visual, warm, content-first:
- **Card-based UI**: Information lives in visual cards, never in plain lists
- **Color gradients**: Each content type has a gradient palette (warm oranges, cool blues, greens, pinks)
- **Search-first**: Search bar is always the hero element, prominent and inviting
- **Zero chrome**: Minimize toggles, segmented controls, labels. Content speaks for itself
- **Generous typography**: Large titles, comfortable line spacing, content that breathes
- **Soft shadows**: No hard borders. Cards float on subtle shadows
- **Tags as color pills**: Deterministic colors per tag, small and unobtrusive
- **Dark-first palette**: Deep dark backgrounds (#000000, #1A1A1A), warm accent (#FF6B35)

### III. MeowTheme Compliance
All views use `MeowTheme` for colors, typography, and spacing. Dark-first palette (#000000 bg, #2F2F2F surface, #FFFFFF text). No hardcoded magic numbers — use theme constants. The app must feel like one coherent product.

### IV. Platform-Adaptive Layout
iOS and macOS share a single codebase. Use `#if os(iOS)` / `#if os(macOS)` for platform differences. iOS = full-screen, touch-first. macOS = split views, keyboard-first. Never force one platform's UX onto the other.

### V. 4 Laws (Non-Negotiable)
- Functions: max 20 lines
- Files: max 300 lines
- Organization: domain-driven (by feature, not by tech layer)
- Names: self-documenting (`verbNoun`, `PascalCase`, `UPPER_SNAKE`)

### VI. Existing Architecture Respect
New features MUST follow existing patterns:
- `@Observable` ViewModels (not ObservableObject, not @StateObject)
- Feature folders under `Sources/Features/`
- API calls through `MeowAPIClient`
- SwiftData for offline caching
- NavigationStack for routing

### VII. Performance-First on macOS
macOS is the fragile platform (NSScrollView CPU sensitivity, layout loops). All views must:
- Avoid `NSTextView` entirely (use native `Text(AttributedString)`)
- Never trigger `invalidateIntrinsicContentSize` in render loops
- Cache computed AttributedStrings via `NSCache`
- Disable spring animations on macOS

## Technical Constraints

- **Platforms**: iOS 17+ / macOS 14+
- **Swift**: 6.0 with strict concurrency
- **State**: `@Observable` macro, `@MainActor` for UI state
- **Networking**: REST via `MeowAPIClient`, WebSocket for real-time
- **Persistence**: SwiftData (offline-first, sync on connect)
- **Build**: xcodegen from `project.yml` — never edit `.xcodeproj` directly
- **Graph Rendering**: SwiftUI Canvas + force-directed layout

## Quality Gates

- Swift strict concurrency on client, TypeScript strict on server
- No implicit `any` types
- All API responses must have `Codable` models
- Error states for every async operation (loading, empty, error, content)
- VoiceOver accessibility labels on interactive elements

## Governance

This constitution governs all NamiOS UI development. Amendments require updating this document and documenting rationale in `documentation/decisions/`.

**Version**: 2.0.0 | **Ratified**: 2026-02-28 | **Last Amended**: 2026-02-28
