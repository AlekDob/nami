import SwiftUI

enum MeowTheme {
    // MARK: - Dark Mode

    enum Dark {
        static let background = Color(hex: 0x0D0D0D)
        static let surface = Color(hex: 0x1A1A1A)
        static let surfaceHover = Color(hex: 0x222222)
        static let border = Color.white.opacity(0.08)
        static let textPrimary = Color(hex: 0xECECEC)
        static let textSecondary = Color(hex: 0x8E8E8E)
        static let textMuted = Color(hex: 0x555555)
    }

    // MARK: - Light Mode

    enum Light {
        static let background = Color(hex: 0xFFFFFF)
        static let surface = Color(hex: 0xF7F7F8)
        static let surfaceHover = Color(hex: 0xEFEFF0)
        static let border = Color.black.opacity(0.06)
        static let textPrimary = Color(hex: 0x1A1A1A)
        static let textSecondary = Color(hex: 0x6E6E6E)
        static let textMuted = Color(hex: 0xA0A0A0)
    }

    // MARK: - Accent (minimal — one tint)

    static let accent = Color(hex: 0x10A37F)
    static let red = Color(hex: 0xEF4444)
    static let yellow = Color(hex: 0xF59E0B)
    static let green = Color(hex: 0x10B981)

    // MARK: - Typography

    static let body = Font.system(.body, design: .default)
    static let bodySmall = Font.system(.caption, design: .default)
    static let bodyMedium = Font.system(.subheadline, design: .default)
    static let title = Font.system(.title2, weight: .semibold)
    static let headline = Font.system(.headline, weight: .medium)
    static let mono = Font.system(.body, design: .monospaced)
    static let monoSmall = Font.system(.caption, design: .monospaced)

    // MARK: - Spacing

    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32

    // MARK: - Corners

    static let cornerSM: CGFloat = 8
    static let cornerMD: CGFloat = 12
    static let cornerLG: CGFloat = 16
}

// MARK: - Color Extension

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}

// MARK: - Adaptive Colors

struct AdaptiveColors {
    @Environment(\.colorScheme) private var colorScheme

    var bg: Color { colorScheme == .dark ? MeowTheme.Dark.background : MeowTheme.Light.background }
    var surface: Color { colorScheme == .dark ? MeowTheme.Dark.surface : MeowTheme.Light.surface }
    var border: Color { colorScheme == .dark ? MeowTheme.Dark.border : MeowTheme.Light.border }
    var text: Color { colorScheme == .dark ? MeowTheme.Dark.textPrimary : MeowTheme.Light.textPrimary }
    var textSecondary: Color { colorScheme == .dark ? MeowTheme.Dark.textSecondary : MeowTheme.Light.textSecondary }
    var textMuted: Color { colorScheme == .dark ? MeowTheme.Dark.textMuted : MeowTheme.Light.textMuted }
}

// MARK: - Backward Compat Aliases

extension MeowTheme {
    static let cyan = accent
    static let violet = accent
    static let magenta = red
    static let bodyFont = body
    static let headlineFont = headline
    static let titleFont = title
    static let bodyLarge = title
    static let monoFont = mono
    static let accentGradient = LinearGradient(colors: [accent], startPoint: .leading, endPoint: .trailing)
    static let subtleGradient = LinearGradient(colors: [accent.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
    static let cornerRadiusSM = cornerSM
    static let cornerRadiusMD = cornerMD
    static let cornerRadiusLG = cornerLG
}

// MARK: - MeowColors ViewModifier

struct MeowColors: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    var background: Color { colorScheme == .dark ? MeowTheme.Dark.background : MeowTheme.Light.background }
    var surface: Color { colorScheme == .dark ? MeowTheme.Dark.surface : MeowTheme.Light.surface }
    var border: Color { colorScheme == .dark ? MeowTheme.Dark.border : MeowTheme.Light.border }
    var textPrimary: Color { colorScheme == .dark ? MeowTheme.Dark.textPrimary : MeowTheme.Light.textPrimary }
    var textSecondary: Color { colorScheme == .dark ? MeowTheme.Dark.textSecondary : MeowTheme.Light.textSecondary }

    func body(content: Content) -> some View { content }
}
