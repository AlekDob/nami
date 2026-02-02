import SwiftUI

struct TypingIndicator: View {
    @State private var activeIndex = 0
    @Environment(\.colorScheme) private var colorScheme

    private let dotCount = 3
    private let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: MeowTheme.spacingXS) {
            Text("(-.-)")
                .font(MeowTheme.monoSmall)
                .foregroundColor(mutedColor)

            HStack(spacing: 4) {
                ForEach(0..<dotCount, id: \.self) { index in
                    Circle()
                        .fill(MeowTheme.accent)
                        .frame(width: 6, height: 6)
                        .scaleEffect(activeIndex == index ? 1.3 : 0.7)
                        .opacity(activeIndex == index ? 1 : 0.4)
                        .animation(
                            .spring(response: 0.3, dampingFraction: 0.5),
                            value: activeIndex
                        )
                }
            }
        }
        .onReceive(timer) { _ in
            activeIndex = (activeIndex + 1) % dotCount
        }
    }

    private var mutedColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.textMuted : MeowTheme.Light.textMuted
    }
}
