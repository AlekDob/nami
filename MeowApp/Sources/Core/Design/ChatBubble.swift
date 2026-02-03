import SwiftUI

struct ChatBubble: View {
    let content: MessageContent
    let isUser: Bool
    let stats: ChatStats?
    let toolsUsed: [String]?
    let messageID: UUID?
    let tts: TextToSpeechService?

    @Environment(\.colorScheme) private var colorScheme

    init(content: MessageContent, isUser: Bool, stats: ChatStats? = nil, toolsUsed: [String]? = nil, messageID: UUID? = nil, tts: TextToSpeechService? = nil) {
        self.content = content
        self.isUser = isUser
        self.stats = stats
        self.toolsUsed = toolsUsed
        self.messageID = messageID
        self.tts = tts
    }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
            if content.hasImages { imageGrid }
            if !content.textContent.isEmpty { textBody }
            if !isUser { actionRow }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    @ViewBuilder
    private var textBody: some View {
        if isUser {
            // User: dark gray rounded pill
            Text(content.textContent)
                .font(.body)
                .foregroundColor(primaryColor)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(surfaceColor)
                .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerLG, style: .continuous))
        } else {
            // Assistant: no background, just text
            MarkdownText(content: content.textContent, textColor: primaryColor)
        }
    }

    // MARK: - Action Row (ChatGPT style icons below assistant msg)

    @ViewBuilder
    private var actionRow: some View {
        HStack(spacing: 14) {
            if let tts, let messageID {
                actionIcon(tts.speakingMessageID == messageID && tts.isSpeaking
                           ? "stop.fill" : "speaker.wave.2",
                           action: { tts.toggleSpeak(content.textContent, messageID: messageID) })
            }
            if let tools = toolsUsed, !tools.isEmpty {
                ForEach(tools, id: \.self) { tool in
                    Text(toolLabel(tool))
                        .font(.caption2)
                        .foregroundColor(mutedColor)
                }
            }
            if let stats { statsLabel(stats) }
        }
    }

    private func actionIcon(_ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(mutedColor)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var imageGrid: some View {
        HStack(spacing: 6) {
            ForEach(Array(content.images.enumerated()), id: \.offset) { _, base64 in
                if let img = ImageCompressor.decodeBase64Image(base64) {
                    #if canImport(UIKit)
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerSM))
                    #else
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 200, maxHeight: 200)
                        .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerSM))
                    #endif
                }
            }
        }
    }

    private func toolLabel(_ tool: String) -> String {
        tool.replacingOccurrences(
            of: "([a-z])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        ).lowercased()
    }

    private func statsLabel(_ stats: ChatStats) -> some View {
        HStack(spacing: 4) {
            if let model = stats.model { Text(model) }
            if let tokens = stats.outputTokens { Text("\(tokens) tok") }
            if let duration = stats.durationMs { Text("\(duration)ms") }
        }
        .font(.caption2)
        .foregroundColor(mutedColor)
    }

    private var primaryColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.textPrimary : MeowTheme.Light.textPrimary
    }

    private var surfaceColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.surface : MeowTheme.Light.surface
    }

    private var mutedColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.textMuted : MeowTheme.Light.textMuted
    }
}
