import SwiftUI

struct TypingIndicator: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var glyphs: [String] = ["_", "_", "_", "_", "_"]
    @State private var opacity: [Double] = [0, 0, 0, 0, 0]
    @State private var timer: Timer?

    private let charset = ["_", "|", "/", "\\", "-", ".", ":", "*", "~", ">", "<", "^"]

    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            ForEach(0..<5, id: \.self) { i in
                Text(glyphs[i])
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundColor(textColor)
                    .opacity(opacity[i])
            }
        }
        .padding(.leading, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { startGlitch() }
        .onDisappear { timer?.invalidate(); timer = nil }
    }

    private func startGlitch() {
        // Staggered fade-in
        for i in 0..<5 {
            withAnimation(.easeOut(duration: 0.3).delay(Double(i) * 0.08)) {
                opacity[i] = 1.0
            }
        }

        // Cycling glyphs at random intervals
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [charset] _ in
            let idx = Int.random(in: 0..<5)
            let glyph = charset.randomElement() ?? "_"
            DispatchQueue.main.async {
                withAnimation(.easeInOut(duration: 0.05)) {
                    glyphs[idx] = glyph
                }
            }
        }
    }
}
