import SwiftUI
import AVFoundation

// MARK: - Nami Interactive View

/// Full-screen interactive view for voice conversation with Nami
struct NamiInteractiveView: View {
    let apiClient: MeowAPIClient
    @Binding var namiProps: NamiProps
    let namiLevel: Int
    var onMenuTap: (() -> Void)?

    @State private var speechRecognizer = SpeechRecognizer()
    @State private var ttsService = TextToSpeechService()
    @State private var isHolding = false
    @State private var namiState: NamiState = .idle
    @State private var transcript = ""
    @State private var fullResponseText = ""
    @State private var displayedResponseText = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var conversationHistory: [ChatMessage] = []
    @State private var typewriterTask: Task<Void, Never>?
    @State private var hasInteracted = false

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer().frame(height: MeowTheme.spacingLG)

                    namiEntitySection

                    statusSection

                    Spacer().frame(height: MeowTheme.spacingMD)

                    conversationSection
                        .frame(maxHeight: .infinity, alignment: .top)

                    instructionsSection
                }
                .padding(.horizontal, MeowTheme.spacingLG)
            }
            .toolbar { toolbarContent }
            .onAppear { setupSpeechRecognizer() }
        }
    }

    // MARK: - Nami Entity

    private var namiEntitySection: some View {
        NamiEntityView(
            props: namiProps,
            state: namiState,
            level: namiLevel,
            size: 200,
            audioLevel: currentAudioLevel,
            disableTouch: true
        )
        .contentShape(Circle())
        .gesture(holdToTalkGesture)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: namiState)
    }

    private var holdToTalkGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                if !isHolding && !isProcessing {
                    startListening()
                }
            }
            .onEnded { _ in
                if isHolding {
                    stopListening()
                }
            }
    }

    private var currentAudioLevel: CGFloat {
        if ttsService.isSpeaking {
            return ttsService.audioLevel
        } else if speechRecognizer.isRecording {
            return CGFloat(speechRecognizer.audioLevel)
        }
        return 0
    }

    private var showInstructions: Bool {
        !hasInteracted && transcript.isEmpty && displayedResponseText.isEmpty
    }

    // MARK: - Status Section

    private var statusSection: some View {
        Text(statusText)
            .font(.subheadline)
            .foregroundColor(mutedColor)
            .padding(.top, MeowTheme.spacingSM)
    }

    private var statusText: String {
        if let error = errorMessage {
            return error
        }
        switch namiState {
        case .listening:
            return "Ti ascolto..."
        case .thinking:
            return "Sto pensando..."
        case .speaking:
            return ""
        default:
            return ""
        }
    }

    // MARK: - Conversation Section

    private var conversationSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: MeowTheme.spacingMD) {
                    if !transcript.isEmpty {
                        HStack {
                            Spacer()
                            Text(transcript)
                                .font(.body)
                                .foregroundColor(primaryColor)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(surfaceColor)
                                .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerLG, style: .continuous))
                        }
                    }

                    if !displayedResponseText.isEmpty {
                        Text(displayedResponseText)
                            .font(.body)
                            .foregroundColor(primaryColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("response")
                    }
                }
                .padding(.top, MeowTheme.spacingSM)
            }
            .scrollIndicators(.hidden)
            .onChange(of: displayedResponseText) {
                withAnimation(.easeOut(duration: 0.1)) {
                    proxy.scrollTo("response", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Instructions

    @ViewBuilder
    private var instructionsSection: some View {
        if showInstructions {
            HStack(spacing: MeowTheme.spacingSM) {
                Image(systemName: "hand.tap.fill")
                    .foregroundColor(mutedColor.opacity(0.6))
                Text("Tieni premuto su \(namiProps.name)")
                    .font(.caption)
                    .foregroundColor(mutedColor)
            }
            .padding(.bottom, MeowTheme.spacingLG)
            .transition(.opacity)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button { onMenuTap?() } label: {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(primaryColor)
            }
        }
        ToolbarItem(placement: .principal) {
            Text(namiProps.name)
                .font(.headline)
                .foregroundColor(primaryColor)
        }
    }

    // MARK: - Voice Logic

    private func setupSpeechRecognizer() {
        speechRecognizer.requestPermissions()
    }

    private func startListening() {
        guard !isProcessing else { return }
        guard speechRecognizer.isAvailable else {
            errorMessage = speechRecognizer.permissionErrorMessage
            triggerHaptic(.error)
            return
        }

        typewriterTask?.cancel()
        typewriterTask = nil
        ttsService.stop()

        hasInteracted = true
        isHolding = true
        transcript = ""
        fullResponseText = ""
        displayedResponseText = ""
        errorMessage = nil
        namiState = .listening

        triggerHaptic(.heavy)
        speechRecognizer.startRecording()
    }

    private func stopListening() {
        guard isHolding else { return }
        isHolding = false

        triggerHaptic(.medium)
        speechRecognizer.stopRecording()

        let finalTranscript = speechRecognizer.transcript
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if finalTranscript.isEmpty {
            namiState = .idle
            return
        }

        transcript = finalTranscript
        processVoiceInput(finalTranscript)
    }

    private func processVoiceInput(_ text: String) {
        isProcessing = true
        namiState = .thinking

        let userMessage = ChatMessage(role: .user, content: text)
        conversationHistory.append(userMessage)

        Task {
            do {
                let response = try await apiClient.sendChat(messages: conversationHistory)

                let assistantMessage = ChatMessage(role: .assistant, content: response.text)
                conversationHistory.append(assistantMessage)

                await MainActor.run {
                    fullResponseText = response.text
                    startTypewriterAndSpeak(response.text)
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Errore: \(error.localizedDescription)"
                    namiState = .idle
                    isProcessing = false
                }
            }
        }
    }

    private func startTypewriterAndSpeak(_ text: String) {
        namiState = .speaking

        Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            ttsService.speak(text)

            while ttsService.isSpeaking || ttsService.isLoading {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }

            await MainActor.run {
                namiState = .idle
                isProcessing = false
            }
        }

        typewriterTask = Task {
            let chars = Array(text)
            var displayed = ""

            for char in chars {
                if Task.isCancelled { break }

                displayed.append(char)
                await MainActor.run {
                    displayedResponseText = displayed
                }

                try? await Task.sleep(nanoseconds: 25_000_000)
            }
        }
    }

    private func triggerHaptic(_ style: HapticStyle) {
        #if os(iOS)
        switch style {
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        #endif
    }

    private enum HapticStyle { case heavy, medium, error }

    // MARK: - Colors

    private var bgColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.background : MeowTheme.Light.background
    }

    private var surfaceColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.surface : MeowTheme.Light.surface
    }

    private var primaryColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.textPrimary : MeowTheme.Light.textPrimary
    }

    private var mutedColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.textMuted : MeowTheme.Light.textMuted
    }
}

// MARK: - Preview

#Preview {
    NamiInteractiveView(
        apiClient: MeowAPIClient(),
        namiProps: .constant(.default),
        namiLevel: 5
    )
}
