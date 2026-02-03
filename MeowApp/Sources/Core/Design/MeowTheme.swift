import SwiftUI

enum MeowTheme {
    // MARK: - Dark Mode (Primary — ChatGPT style)

    enum Dark {
        static let background = Color.black
        static let surface = Color(hex: 0x2F2F2F)
        static let surfaceHover = Color(hex: 0x3A3A3A)
        static let inputBg = Color(hex: 0x2F2F2F)
        static let border = Color.white.opacity(0.08)
        static let textPrimary = Color.white
        static let textSecondary = Color(hex: 0xB4B4B4)
        static let textMuted = Color(hex: 0x767676)
    }

    // MARK: - Light Mode

    enum Light {
        static let background = Color.white
        static let surface = Color(hex: 0xF7F7F8)
        static let surfaceHover = Color(hex: 0xEFEFF0)
        static let inputBg = Color(hex: 0xF7F7F8)
        static let border = Color.black.opacity(0.06)
        static let textPrimary = Color.black
        static let textSecondary = Color(hex: 0x6E6E80)
        static let textMuted = Color(hex: 0xACACAD)
    }

    // MARK: - Accents (Minimal)

    static let accent = Color.white
    static let accentDark = Color(hex: 0x2F2F2F)
    static let red = Color(hex: 0xEF4444)
    static let green = Color(hex: 0x10B981)
    static let yellow = Color.orange
    static let purple = Color(hex: 0x9D4EDD)

    // MARK: - Typography (System — SF Pro)

    static let body = Font.body
    static let bodySmall = Font.caption
    static let bodyMedium = Font.subheadline
    static let title = Font.title2.bold()
    static let headline = Font.headline
    static let mono = Font.system(.body, design: .monospaced)
    static let monoSmall = Font.system(.caption, design: .monospaced)

    // MARK: - Spacing

    static let spacingXS: CGFloat = 4
    static let spacingSM: CGFloat = 8
    static let spacingMD: CGFloat = 16
    static let spacingLG: CGFloat = 24
    static let spacingXL: CGFloat = 32

    // MARK: - Corners

    static let cornerSharp: CGFloat = 4
    static let cornerSubtle: CGFloat = 8
    static let cornerSM: CGFloat = 12
    static let cornerMD: CGFloat = 16
    static let cornerLG: CGFloat = 22
    static let cornerPill: CGFloat = 100
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
    static let violet = purple
    static let magenta = red
    static let accentLight = accent.opacity(0.6)
    static let accentBright = accent
    static let orange = Color(hex: 0xFF6B35)
    static let bodyFont = body
    static let headlineFont = headline
    static let titleFont = title
    static let bodyLarge = title
    static let monoFont = mono
    static let serifTitle = title
    static let serifHeadline = headline
    static let accentGradient = LinearGradient(colors: [accent], startPoint: .leading, endPoint: .trailing)
    static let subtleGradient = LinearGradient(colors: [Dark.surface], startPoint: .top, endPoint: .bottom)
    static let cornerRadiusSM = cornerSM
    static let cornerRadiusMD = cornerMD
    static let cornerRadiusLG = cornerLG
    static let gradientDarkStart = Dark.background
    static let gradientDarkEnd = Dark.background
    static let gradientLightStart = Light.background
    static let gradientLightEnd = Light.background
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
