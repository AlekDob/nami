import SwiftUI

// MARK: - Card Modifier (clean surface, no glass)

struct GlassCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    let cornerRadius: CGFloat
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(colorScheme == .dark ? MeowTheme.Dark.surface : MeowTheme.Light.surface)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(colorScheme == .dark ? MeowTheme.Dark.border : MeowTheme.Light.border, lineWidth: 1)
            )
    }
}

// MARK: - Input Modifier (clean)

struct GlassInputModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(colorScheme == .dark ? MeowTheme.Dark.surface : MeowTheme.Light.surface)
            .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerSM, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: MeowTheme.cornerSM, style: .continuous)
                    .stroke(colorScheme == .dark ? MeowTheme.Dark.border : MeowTheme.Light.border, lineWidth: 1)
            )
    }
}

// MARK: - View Extensions

extension View {
    func glassCard(
        cornerRadius: CGFloat = MeowTheme.cornerMD,
        padding: CGFloat = MeowTheme.spacingMD
    ) -> some View {
        modifier(GlassCardModifier(cornerRadius: cornerRadius, padding: padding))
    }

    func glassInput() -> some View {
        modifier(GlassInputModifier())
    }

    func gradientText(_ gradient: LinearGradient = MeowTheme.accentGradient) -> some View {
        self.foregroundColor(MeowTheme.accent)
    }

    func staggeredAppear(index: Int) -> some View {
        modifier(StaggeredAppearModifier(index: index))
    }
}

// MARK: - Staggered Appear Modifier

struct StaggeredAppearModifier: ViewModifier {
    let index: Int
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 16)
            .onAppear {
                let delay = Double(min(index, 10)) * 0.05
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(delay)) {
                    appeared = true
                }
            }
    }
}
