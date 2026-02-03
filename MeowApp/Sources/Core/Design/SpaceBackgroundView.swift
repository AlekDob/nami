import SwiftUI

/// Animated star field background for the space theme.
/// Uses seeded random positions and staggered twinkle animations.
struct SpaceBackgroundView: View {
    @State private var twinklePhase = false

    private let starCount = 25
    private let seed: UInt64 = 42

    var body: some View {
        Canvas { context, size in
            var rng = SeededRNG(seed: seed)
            for i in 0..<starCount {
                let x = CGFloat.random(in: 0...size.width, using: &rng)
                let y = CGFloat.random(in: 0...size.height, using: &rng)
                let baseRadius = CGFloat.random(in: 0.5...1.5, using: &rng)
                let phase = Double(i) / Double(starCount)
                let opacity = twinklePhase
                    ? 0.2 + 0.4 * sin(.pi * phase)
                    : 0.1 + 0.3 * cos(.pi * phase)

                let starRect = CGRect(
                    x: x - baseRadius,
                    y: y - baseRadius,
                    width: baseRadius * 2,
                    height: baseRadius * 2
                )
                let starPath = Circle().path(in: starRect)
                context.fill(starPath, with: .color(.white.opacity(opacity)))
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 3.0).repeatForever(autoreverses: true)) {
                twinklePhase = true
            }
        }
    }
}

// MARK: - Seeded RNG for deterministic star positions

private struct SeededRNG: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
