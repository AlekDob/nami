import SwiftUI
import PhotosUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    var onMenuTap: (() -> Void)?
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isInputFocused: Bool
    @State private var sendTapped = false

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                chatHeader
                messagesList
                if viewModel.isThinking {
                    if !viewModel.activeTools.isEmpty {
                        toolActivityRow
                            .transition(.opacity)
                    }
                    thinkingRow
                        .transition(.opacity)
                }
                if viewModel.speechRecognizer.isRecording {
                    voiceRecordingBar
                        .transition(.opacity)
                }
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }
                inputBar
            }
        }
        .animation(.easeInOut(duration: 0.2), value: viewModel.isThinking)
        .animation(
            .easeInOut(duration: 0.15),
            value: viewModel.activeTools.count
        )
        .onTapGesture {
            // Dismiss keyboard when tapping outside input field
            // Using onTapGesture instead of simultaneousGesture
            // to not interfere with long-press/copy-paste menu
            isInputFocused = false
        }
    }

    // MARK: - Header (ChatGPT style)

    private var chatHeader: some View {
        HStack(spacing: 0) {
            // Hamburger menu (left)
            Button { onMenuTap?() } label: {
                Image(systemName: "line.3.horizontal")
                    .font(.title3)
                    .foregroundColor(primaryColor)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)

            Spacer()

            // Center: "Meow" + ASCII cat
            HStack(spacing: 8) {
                Text("Meow")
                    .font(.headline)
                    .foregroundColor(primaryColor)
                ASCIICatView(
                    mood: viewModel.isThinking ? .thinking : .idle,
                    size: .small
                )
            }

            Spacer()

            // New chat (right)
            Button { viewModel.clearChat() } label: {
                Image(systemName: "square.and.pencil")
                    .font(.title3)
                    .foregroundColor(mutedColor)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
            .opacity(viewModel.messages.isEmpty ? 0 : 1)
        }
        .padding(.horizontal, MeowTheme.spacingSM)
        .padding(.vertical, MeowTheme.spacingXS)
    }

    // MARK: - Messages

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: MeowTheme.spacingMD + 4) {
                    if viewModel.messages.isEmpty { emptyState }
                    ForEach(
                        Array(viewModel.messages.enumerated()),
                        id: \.element.id
                    ) { index, message in
                        let isLatest =
                            index == viewModel.messages.count - 1
                        MessageRow(
                            message: message,
                            stats: viewModel.lastStats,
                            toolsUsed: viewModel.lastToolsUsed,
                            isLatest: isLatest,
                            tts: viewModel.tts
                        )
                        .id(message.id)
                    }
                }
                .padding(.vertical, MeowTheme.spacingMD)
            }
            .onChange(of: viewModel.messages.count) {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: MeowTheme.spacingLG) {
            ASCIICatView(mood: .idle, size: .large)
            Text("What can I help with?")
                .font(.title3)
                .foregroundColor(mutedColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
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
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(MeowTheme.red)
            Text(message)
                .font(.subheadline)
                .foregroundColor(MeowTheme.red)
        }
        .lineLimit(2)
        .padding(.horizontal, MeowTheme.spacingMD)
        .padding(.vertical, MeowTheme.spacingSM)
    }

    // MARK: - Voice Recording Bar

    private var voiceRecordingBar: some View {
        HStack(spacing: MeowTheme.spacingSM) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
            WaveformView(
                audioLevel: viewModel.speechRecognizer.audioLevel,
                isRecording: viewModel.speechRecognizer.isRecording
            )
            Text(
                viewModel.speechRecognizer.transcript.isEmpty
                    ? "Listening..."
                    : viewModel.speechRecognizer.transcript
            )
            .font(.subheadline)
            .foregroundColor(secondaryColor)
            .lineLimit(2)
            Spacer()
        }
        .padding(.horizontal, MeowTheme.spacingMD)
        .padding(.vertical, MeowTheme.spacingSM)
    }

    // MARK: - Input Bar (ChatGPT style)

    private var inputBar: some View {
        VStack(spacing: 0) {
            if !viewModel.pendingImages.isEmpty {
                pendingImagesStrip
            }
            inputRow
        }
        .padding(.horizontal, MeowTheme.spacingSM + 4)
        .padding(.bottom, MeowTheme.spacingSM)
    }

    private var pendingImagesStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(
                    Array(viewModel.pendingImages.enumerated()),
                    id: \.offset
                ) { index, image in
                    ZStack(alignment: .topTrailing) {
                        #if canImport(UIKit)
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: MeowTheme.cornerSubtle
                                )
                            )
                        #else
                        Image(nsImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(
                                RoundedRectangle(
                                    cornerRadius: MeowTheme.cornerSubtle
                                )
                            )
                        #endif
                        Button {
                            viewModel.removeImage(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.subheadline)
                                .foregroundColor(.white)
                                .shadow(radius: 2)
                        }
                        .buttonStyle(.plain)
                        .offset(x: 4, y: -4)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    private var inputRow: some View {
        HStack(spacing: MeowTheme.spacingSM) {
            // + button (photos/attachments)
            PhotosPicker(
                selection: $viewModel.selectedPhotoItems,
                maxSelectionCount:
                    ImageCompressor.maxImages
                    - viewModel.pendingImages.count,
                matching: .images
            ) {
                Image(systemName: "plus")
                    .font(.title3.weight(.medium))
                    .foregroundColor(primaryColor)
                    .frame(width: 36, height: 36)
                    .background(surfaceColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .onChange(of: viewModel.selectedPhotoItems) {
                Task { await viewModel.handlePhotoSelection() }
            }

            // Input pill
            HStack(spacing: 6) {
                TextField(
                    "Message",
                    text: $viewModel.inputText,
                    axis: .vertical
                )
                .font(.body)
                .lineLimit(1...5)
                .textFieldStyle(.plain)
                .focused($isInputFocused)
                .onSubmit {
                    if viewModel.canSend { triggerSend() }
                }

                // Mic button (inside pill)
                VoiceInputButton(
                    isRecording: viewModel.speechRecognizer.isRecording,
                    audioLevel: viewModel.speechRecognizer.audioLevel,
                    onTap: { viewModel.toggleVoiceInput() }
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(
                    cornerRadius: MeowTheme.cornerLG,
                    style: .continuous
                )
                .fill(surfaceColor)
            )

            // Send button
            Button { triggerSend() } label: {
                Image(systemName: "arrow.up")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(
                        viewModel.canSend ? bgColor : mutedColor
                    )
                    .frame(width: 36, height: 36)
                    .background(
                        viewModel.canSend ? primaryColor : surfaceColor
                    )
                    .clipShape(Circle())
                    .scaleEffect(sendTapped ? 0.85 : 1)
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSend)
        }
    }

    private func triggerSend() {
        guard viewModel.canSend else { return }
        withAnimation(.easeInOut(duration: 0.1)) { sendTapped = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.easeInOut(duration: 0.1)) {
                sendTapped = false
            }
            viewModel.sendMessage()
        }
    }

    // MARK: - Helpers

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let lastID = viewModel.messages.last?.id else { return }
        withAnimation(.easeOut(duration: 0.3)) {
            proxy.scrollTo(lastID, anchor: .bottom)
        }
    }

    private var bgColor: Color {
        colorScheme == .dark
            ? MeowTheme.Dark.background
            : MeowTheme.Light.background
    }

    private var primaryColor: Color {
        colorScheme == .dark
            ? MeowTheme.Dark.textPrimary
            : MeowTheme.Light.textPrimary
    }

    private var secondaryColor: Color {
        colorScheme == .dark
            ? MeowTheme.Dark.textSecondary
            : MeowTheme.Light.textSecondary
    }

    private var mutedColor: Color {
        colorScheme == .dark
            ? MeowTheme.Dark.textMuted
            : MeowTheme.Light.textMuted
    }

    private var surfaceColor: Color {
        colorScheme == .dark
            ? MeowTheme.Dark.surface
            : MeowTheme.Light.surface
    }
}
