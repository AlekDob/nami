import SwiftUI

// MARK: - Nami Splash View

/// Splash screen featuring the Nami wave entity with wake-up animation
struct NamiSplashView: View {
    let props: NamiProps
    let level: Int

    @State private var isWakingUp = false
    @State private var opacity: Double = 0
    @State private var scale: Double = 0.8
    @State private var textOpacity: Double = 0
    @Environment(\.colorScheme) private var colorScheme

    private var bgColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.background : MeowTheme.Light.background
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: MeowTheme.spacingLG) {
                Spacer()

                // Nami entity
                NamiEntityView(
                    props: props,
                    state: isWakingUp ? .thinking : .idle,
                    level: level,
                    size: 200
                )
                .opacity(opacity)
                .scaleEffect(scale)

                // Name and status
                VStack(spacing: MeowTheme.spacingSM) {
                    Text(props.name)
                        .font(.title.bold())
                        .foregroundColor(.primary)

                    Text(isWakingUp ? "Rising..." : "Ready")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .opacity(textOpacity)

                Spacer()
            }
        }
        .onAppear {
            startWakeUpAnimation()
        }
    }

    private func startWakeUpAnimation() {
        withAnimation(.easeOut(duration: 0.6)) {
            opacity = 1.0
            scale = 1.0
        }

        withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
            textOpacity = 1.0
        }

        withAnimation(.easeInOut(duration: 0.2).delay(0.4)) {
            isWakingUp = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeOut(duration: 0.3)) {
                isWakingUp = false
            }
        }
    }
}

// MARK: - Nami Lock View

/// Lock screen with Nami entity and unlock button
struct NamiLockView: View {
    let props: NamiProps
    let level: Int
    let onUnlock: () -> Void

    @State private var isUnlocking = false
    @Environment(\.colorScheme) private var colorScheme

    private var bgColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.background : MeowTheme.Light.background
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: MeowTheme.spacingLG) {
                Spacer()

                NamiEntityView(
                    props: props,
                    state: isUnlocking ? .thinking : .idle,
                    level: level,
                    size: 180
                )

                VStack(spacing: MeowTheme.spacingSM) {
                    Text(props.name)
                        .font(.title2.bold())
                        .foregroundColor(.primary)

                    Text("Unlock to continue")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button(action: {
                    isUnlocking = true
                    onUnlock()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "faceid")
                        Text("Unlock")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 14)
                    .background(MeowTheme.green)
                    .clipShape(Capsule())
                }
                .padding(.bottom, 60)
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isUnlocking = true
                onUnlock()
            }
        }
    }
}

// MARK: - Mini Nami (for header)

/// Small Nami entity for header bar
struct MiniNamiView: View {
    let props: NamiProps
    let state: NamiState
    let level: Int
    var audioLevel: CGFloat = 0.0

    var body: some View {
        NamiEntityView(
            props: props,
            state: state,
            level: level,
            size: 32,
            audioLevel: audioLevel
        )
    }
}

// MARK: - Preview

#Preview("Splash") {
    NamiSplashView(
        props: NamiProps(
            name: "Nami",
            personality: .donna,
            dominantColor: "#00BFFF",
            secondaryColor: "#0077BE",
            formStyle: .wave,
            voiceId: "Sarah",
            language: "it"
        ),
        level: 5
    )
}

#Preview("Lock") {
    NamiLockView(
        props: .default,
        level: 3,
        onUnlock: { print("unlock") }
    )
}
