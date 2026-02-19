---
type: pattern
tags: [swiftui, markdown, light-mode, accessibility]
date: 2026-02-05
---

# Pattern: SwiftUI Light Mode Code Blocks with High Contrast

## Problem

Code blocks in Markdown rendering have poor contrast in light mode. Light gray backgrounds don't convey "code" semantically.

## Solution

Always use **dark background with light text** for code blocks, regardless of color scheme:

```swift
private struct CodeBlockView: View {
    let code: String
    let colorScheme: ColorScheme

    private var backgroundColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.1)
            : Color(red: 0.15, green: 0.15, blue: 0.15)  // Almost black
    }

    private var textColor: Color {
        Color.white.opacity(0.9)  // Light text in both modes
    }

    var body: some View {
        Text(code)
            .font(MeowTheme.mono)
            .foregroundColor(textColor)
            .padding(MeowTheme.spacingSM)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerSM))
    }
}
```

## Key Points

1. **Background**: Dark in both modes (lighter opacity in dark mode for distinction)
2. **Text**: White/light in both modes
3. **Contrast ratio**: Meets WCAG AA (4.5:1) in both modes
4. **Consistency**: Code always looks like "code" (terminal-like)

## Related

- `Sources/Core/Design/MarkdownText.swift` — implementation
