import SwiftUI

struct VoiceInputButton: View {
    let isRecording: Bool
    let audioLevel: Float
    let onTap: () -> Void

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        Button(action: onTap) {
            ZStack {
                if isRecording {
                    waveformRings
                }
                micIcon
            }
            .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .onChange(of: isRecording) { _, recording in
            if recording { startPulse() } else { stopPulse() }
        }
    }

    // MARK: - Mic Icon

    private var micIcon: some View {
        Image(systemName: isRecording ? "mic.fill" : "mic")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(isRecording ? .white : MeowTheme.accent)
            .frame(width: 32, height: 32)
            .background(isRecording ? MeowTheme.red : MeowTheme.accent.opacity(0.15))
            .clipShape(Circle())
            .scaleEffect(isRecording ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isRecording)
    }

    // MARK: - Waveform Rings

    private var waveformRings: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { ring in
                Circle()
                    .stroke(MeowTheme.red.opacity(ringOpacity(ring)), lineWidth: 1.5)
                    .frame(width: ringSize(ring), height: ringSize(ring))
                    .scaleEffect(pulseScale)
            }
        }
    }

    private func ringSize(_ index: Int) -> CGFloat {
        let base: CGFloat = 38 + CGFloat(index) * 10
        let levelBoost = CGFloat(audioLevel) * 8
        return base + levelBoost
    }

    private func ringOpacity(_ index: Int) -> Double {
        let base = 0.4 - Double(index) * 0.12
        return max(base + Double(audioLevel) * 0.2, 0.05)
    }

    private func startPulse() {
        withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
            pulseScale = 1.1
        }
    }

    private func stopPulse() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            pulseScale = 1.0
        }
    }
}

// MARK: - Waveform Bar Visualizer

struct WaveformView: View {
    let audioLevel: Float
    let isRecording: Bool
    let barCount: Int = 5

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<barCount, id: \.self) { index in
                WaveformBar(
                    audioLevel: audioLevel,
                    index: index,
                    isRecording: isRecording
                )
            }
        }
        .frame(height: 20)
    }
}

private struct WaveformBar: View {
    let audioLevel: Float
    let index: Int
    let isRecording: Bool

    @State private var animatedHeight: CGFloat = 3

    var body: some View {
        RoundedRectangle(cornerRadius: 1.5)
            .fill(MeowTheme.red.opacity(0.8))
            .frame(width: 3, height: animatedHeight)
            .onChange(of: audioLevel) { _, level in
                guard isRecording else { return }
                let variation = Float.random(in: 0.5...1.5)
                let height = max(3, CGFloat(level * variation) * 18)
                withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                    animatedHeight = height
                }
            }
            .onChange(of: isRecording) { _, recording in
                if !recording {
                    withAnimation(.easeOut(duration: 0.2)) {
                        animatedHeight = 3
                    }
                }
            }
    }
}
