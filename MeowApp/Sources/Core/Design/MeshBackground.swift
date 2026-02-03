import SwiftUI

/// Solid background — ChatGPT style (no gradient).
struct MeshGradientBackground: View {
    var isAnimating: Bool = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        (colorScheme == .dark ? MeowTheme.Dark.background : MeowTheme.Light.background)
            .ignoresSafeArea()
    }
}
