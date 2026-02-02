import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isInputFocused: Bool
    @State private var sendTapped = false

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            Divider()
            messagesList
            if viewModel.isThinking {
                if !viewModel.activeTools.isEmpty {
                    toolActivityRow
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
                thinkingRow
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if viewModel.speechRecognizer.isRecording {
                voiceRecordingBar
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            if let error = viewModel.errorMessage { errorBanner(error) }
            Divider()
            inputBar
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isThinking)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: viewModel.activeTools.count)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.speechRecognizer.isRecording)
        .background(bgColor)
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture().onEnded { isInputFocused = false }
        )
    }

    // MARK: - Header

    private var chatHeader: some View {
        HStack(spacing: MeowTheme.spacingSM) {
            ASCIICatView(mood: viewModel.catMood, size: .small)
            Text("meow")
                .font(MeowTheme.headline)
                .foregroundColor(primaryColor)
            Spacer()
            if !viewModel.messages.isEmpty {
                Button { viewModel.clearChat() } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(secondaryColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, MeowTheme.spacingMD)
        .padding(.vertical, MeowTheme.spacingSM + 4)
    }

    // MARK: - Messages

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: MeowTheme.spacingSM + 2) {
                    if viewModel.messages.isEmpty { emptyState }
                    ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                        let isLatest = index == viewModel.messages.count - 1
                        MessageRow(message: message, stats: viewModel.lastStats, toolsUsed: viewModel.lastToolsUsed, isLatest: isLatest)
                            .id(message.id)
                    }
                }
                .padding(.vertical, MeowTheme.spacingMD)
            }
            .onChange(of: viewModel.messages.count) { scrollToBottom(proxy: proxy) }
        }
    }

    private var emptyState: some View {
        VStack(spacing: MeowTheme.spacingMD) {
            ASCIICatView(mood: .idle, size: .large)
            Text("start a conversation")
                .font(MeowTheme.bodySmall)
                .foregroundColor(mutedColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 100)
    }

    private var toolActivityRow: some View {
        HStack {
            ToolActivityView(tools: viewModel.activeTools)
            Spacer()
        }
        .padding(.horizontal, MeowTheme.spacingMD)
        .padding(.vertical, MeowTheme.spacingXS)
    }

    private var thinkingRow: some View {
        HStack {
            TypingIndicator()
            Spacer()
        }
        .padding(.horizontal, MeowTheme.spacingMD)
        .padding(.vertical, MeowTheme.spacingXS)
    }

    private func errorBanner(_ message: String) -> some View {
        Text("! \(message)")
            .font(MeowTheme.bodySmall)
            .foregroundColor(MeowTheme.red)
            .lineLimit(2)
            .padding(.horizontal, MeowTheme.spacingMD)
            .padding(.vertical, MeowTheme.spacingSM)
    }

    // MARK: - Voice Recording Bar

    private var voiceRecordingBar: some View {
        HStack(spacing: MeowTheme.spacingSM) {
            Image(systemName: "mic.fill")
                .foregroundColor(MeowTheme.red)
                .font(.system(size: 12))
            WaveformView(
                audioLevel: viewModel.speechRecognizer.audioLevel,
                isRecording: viewModel.speechRecognizer.isRecording
            )
            Text(viewModel.speechRecognizer.transcript.isEmpty
                 ? "listening..."
                 : viewModel.speechRecognizer.transcript)
                .font(MeowTheme.bodySmall)
                .foregroundColor(secondaryColor)
                .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, MeowTheme.spacingMD)
        .padding(.vertical, MeowTheme.spacingSM)
        .background(MeowTheme.red.opacity(0.05))
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: MeowTheme.spacingSM) {
            VoiceInputButton(
                isRecording: viewModel.speechRecognizer.isRecording,
                audioLevel: viewModel.speechRecognizer.audioLevel,
                onTap: { viewModel.toggleVoiceInput() }
            )

            TextField("message meow...", text: $viewModel.inputText, axis: .vertical)
                .font(MeowTheme.body)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .onSubmit { if viewModel.canSend { triggerSend() } }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: MeowTheme.cornerSM, style: .continuous)
                        .stroke(
                            isInputFocused ? MeowTheme.accent.opacity(0.5) : borderColor,
                            lineWidth: isInputFocused ? 1.5 : 1
                        )
                )

            if isInputFocused && !viewModel.canSend {
                Button { isInputFocused = false } label: {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 16))
                        .foregroundColor(secondaryColor)
                }
                .buttonStyle(.plain)
                .transition(.opacity)
            }

            Button { triggerSend() } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(viewModel.canSend ? MeowTheme.accent : Color.gray.opacity(0.3))
                    .clipShape(Circle())
                    .scaleEffect(sendTapped ? 0.8 : 1)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSend)
        }
        .padding(.horizontal, MeowTheme.spacingMD)
        .padding(.vertical, MeowTheme.spacingSM + 2)
        .animation(.easeInOut(duration: 0.2), value: isInputFocused)
    }

    private func triggerSend() {
        guard viewModel.canSend else { return }
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            sendTapped = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                sendTapped = false
            }
            viewModel.sendMessage()
        }
    }

    // MARK: - Helpers

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastID = viewModel.messages.last?.id else { return }
        withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(lastID, anchor: .bottom) }
    }

    private var bgColor: Color { colorScheme == .dark ? MeowTheme.Dark.background : MeowTheme.Light.background }
    private var primaryColor: Color { colorScheme == .dark ? MeowTheme.Dark.textPrimary : MeowTheme.Light.textPrimary }
    private var secondaryColor: Color { colorScheme == .dark ? MeowTheme.Dark.textSecondary : MeowTheme.Light.textSecondary }
    private var mutedColor: Color { colorScheme == .dark ? MeowTheme.Dark.textMuted : MeowTheme.Light.textMuted }
    private var borderColor: Color { colorScheme == .dark ? MeowTheme.Dark.border : MeowTheme.Light.border }
}
