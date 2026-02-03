import SwiftUI

/// Displays active tool names as subtle text labels.
struct ToolActivityView: View {
    let tools: [String]

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(tools.enumerated()), id: \.offset) { _, tool in
                Text(toolLabel(tool))
                    .font(.caption2)
                    .foregroundColor(mutedColor)
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

    private var mutedColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.textMuted : MeowTheme.Light.textMuted
    }
}
