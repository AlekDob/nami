import SwiftUI

struct MessageRow: View {
    let message: ChatMessage
    let stats: ChatStats?
    let toolsUsed: [String]?
    let isLatest: Bool
    let tts: TextToSpeechService?

    @Environment(\.colorScheme) private var colorScheme
    @State private var appeared = false

    init(message: ChatMessage, stats: ChatStats? = nil, toolsUsed: [String]? = nil, isLatest: Bool = false, tts: TextToSpeechService? = nil) {
        self.message = message
        self.stats = stats
        self.toolsUsed = toolsUsed
        self.isLatest = isLatest
        self.tts = tts
    }

    var body: some View {
        Group {
            switch message.role {
            case .user:     userRow
            case .assistant: assistantRow
            case .system:   systemRow
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                appeared = true
            }
        }
    }

    private var userRow: some View {
        HStack {
            Spacer(minLength: 60)
            ChatBubble(content: message.content, isUser: true)
        }
        .padding(.horizontal, MeowTheme.spacingMD + 4)
    }

    private var assistantRow: some View {
        HStack {
            ChatBubble(
                content: message.content,
                isUser: false,
                stats: isLatest ? stats : nil,
                toolsUsed: isLatest ? toolsUsed : nil,
                messageID: message.id,
                tts: tts
            )
            Spacer(minLength: 60)
        }
        .padding(.horizontal, MeowTheme.spacingMD + 4)
    }

    private var systemRow: some View {
        Text(message.content.textContent)
            .font(.system(size: 13))
            .foregroundColor(colorScheme == .dark ? MeowTheme.Dark.textMuted : MeowTheme.Light.textMuted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, MeowTheme.spacingSM)
            .padding(.horizontal, MeowTheme.spacingMD + 4)
    }
}
