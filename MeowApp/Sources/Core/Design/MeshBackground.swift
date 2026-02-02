import SwiftUI

/// Clean solid background that adapts to color scheme.
/// Replaces the heavy MeshGradient — minimal is better.
struct MeshGradientBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        backgroundColor
            .ignoresSafeArea()
    }

    private var backgroundColor: Color {
        colorScheme == .dark
            ? MeowTheme.Dark.background
            : MeowTheme.Light.background
    }
}

#Preview("Dark") {
    MeshGradientBackground()
        .preferredColorScheme(.dark)
}

#Preview("Light") {
    MeshGradientBackground()
        .preferredColorScheme(.light)
}
