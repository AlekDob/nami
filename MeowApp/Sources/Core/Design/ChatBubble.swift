import SwiftUI

struct ChatBubble: View {
    let content: String
    let isUser: Bool
    let stats: ChatStats?
    let toolsUsed: [String]?

    @Environment(\.colorScheme) private var colorScheme

    init(content: String, isUser: Bool, stats: ChatStats? = nil, toolsUsed: [String]? = nil) {
        self.content = content
        self.isUser = isUser
        self.stats = stats
        self.toolsUsed = toolsUsed
    }

    var body: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: MeowTheme.spacingXS) {
            Group {
                if isUser {
                    Text(content)
                        .font(MeowTheme.body)
                        .foregroundColor(textColor)
                } else {
                    MarkdownText(content: content, textColor: textColor)
                }
            }
            .padding(.horizontal, MeowTheme.spacingMD)
            .padding(.vertical, MeowTheme.spacingSM + 4)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerMD, style: .continuous))

            if let tools = toolsUsed, !tools.isEmpty { toolsRow(tools) }
            if let stats { statsRow(stats) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var textColor: Color {
        isUser ? .white : (colorScheme == .dark ? MeowTheme.Dark.textPrimary : MeowTheme.Light.textPrimary)
    }

    private var bgColor: Color {
        isUser ? MeowTheme.accent : (colorScheme == .dark ? MeowTheme.Dark.surface : MeowTheme.Light.surface)
    }

    private func toolsRow(_ tools: [String]) -> some View {
        FlowLayout(spacing: 4) {
            ForEach(tools, id: \.self) { tool in
                HStack(spacing: 3) {
                    Image(systemName: toolIcon(tool))
                        .font(.system(size: 8))
                    Text(toolLabel(tool))
                        .font(.system(.caption2, design: .monospaced))
                }
                .foregroundColor(MeowTheme.accent)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(MeowTheme.accent.opacity(0.1))
                .clipShape(Capsule())
            }
        }
    }

    private func toolIcon(_ tool: String) -> String {
        let name = tool.lowercased()
        if name.contains("web") || name.contains("fetch") { return "globe" }
        if name.contains("read") || name.contains("file") { return "doc.text" }
        if name.contains("write") { return "square.and.pencil" }
        if name.contains("memory") || name.contains("search") { return "brain" }
        if name.contains("schedule") || name.contains("task") || name.contains("job") { return "clock" }
        if name.contains("email") { return "envelope" }
        if name.contains("x") || name.contains("tweet") || name.contains("browse") { return "bird" }
        return "gearshape"
    }

    private func toolLabel(_ tool: String) -> String {
        tool.replacingOccurrences(
            of: "([a-z])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        ).lowercased()
    }

    private func statsRow(_ stats: ChatStats) -> some View {
        HStack(spacing: MeowTheme.spacingSM) {
            if let model = stats.model { Text(model) }
            if let tokens = stats.outputTokens { Text("\(tokens) tok") }
            if let duration = stats.durationMs { Text("\(duration)ms") }
        }
        .font(MeowTheme.monoSmall)
        .foregroundColor(colorScheme == .dark ? MeowTheme.Dark.textMuted : MeowTheme.Light.textMuted)
    }
}
