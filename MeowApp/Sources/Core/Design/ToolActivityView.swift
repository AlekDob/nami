import SwiftUI

/// Displays animated tool usage indicators during agent processing.
/// Shows each tool as a pill with icon, label, and pulsing animation.
struct ToolActivityView: View {
    let tools: [String]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: MeowTheme.spacingXS) {
            ForEach(Array(tools.enumerated()), id: \.offset) { index, tool in
                ToolPill(tool: tool, index: index, colorScheme: colorScheme)
            }
        }
    }
}

// MARK: - Tool Pill

private struct ToolPill: View {
    let tool: String
    let index: Int
    let colorScheme: ColorScheme

    @State private var isVisible = false
    @State private var isPulsing = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: toolIcon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(MeowTheme.accent)
                .opacity(isPulsing ? 1 : 0.5)

            Text(toolLabel)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(textColor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(surfaceColor.opacity(0.8))
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(MeowTheme.accent.opacity(isPulsing ? 0.3 : 0.1), lineWidth: 1)
        )
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : -8)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7).delay(Double(index) * 0.08)) {
                isVisible = true
            }
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(0.2)) {
                isPulsing = true
            }
        }
    }

    private var toolIcon: String {
        let name = tool.lowercased()
        if name.contains("web") || name.contains("fetch") { return "globe" }
        if name.contains("read") || name.contains("file") { return "doc.text" }
        if name.contains("write") { return "square.and.pencil" }
        if name.contains("memory") || name.contains("search") { return "brain" }
        if name.contains("schedule") || name.contains("task") || name.contains("job") { return "clock" }
        if name.contains("email") { return "envelope" }
        if name.contains("x") || name.contains("tweet") || name.contains("browse") { return "bird" }
        if name.contains("skill") { return "sparkles" }
        if name.contains("cancel") { return "xmark.circle" }
        if name.contains("list") { return "list.bullet" }
        return "gearshape"
    }

    private var toolLabel: String {
        // Convert camelCase to readable: "webFetch" -> "web fetch"
        tool.replacingOccurrences(
            of: "([a-z])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        ).lowercased()
    }

    private var textColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.textSecondary : MeowTheme.Light.textSecondary
    }

    private var surfaceColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.surface : MeowTheme.Light.surface
    }
}
