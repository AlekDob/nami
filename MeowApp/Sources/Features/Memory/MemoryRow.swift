import SwiftUI

struct MemoryRow: View {
    let result: MemoryResult

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: MeowTheme.spacingSM) {
            filePathRow
            snippetText
            metadataRow
        }
        .padding(MeowTheme.spacingSM + 4)
        .background(surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerRadiusSM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MeowTheme.cornerRadiusSM, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private var filePathRow: some View {
        HStack {
            Image(systemName: "doc.text")
                .font(.caption)
                .foregroundColor(MeowTheme.accent)
            Text(result.path)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(MeowTheme.accent)
                .lineLimit(1)
            Spacer()
            scoreLabel
        }
    }

    private var scoreLabel: some View {
        Text(String(format: "%.0f%%", result.score * 100))
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(scoreColor)
            .clipShape(Capsule())
    }

    private var scoreColor: Color {
        if result.score > 0.8 {
            return MeowTheme.green
        }
        if result.score > 0.5 {
            return MeowTheme.yellow
        }
        return MeowTheme.red
    }

    private var snippetText: some View {
        Text(result.snippet)
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(primaryColor)
            .lineLimit(3)
    }

    private var metadataRow: some View {
        HStack(spacing: MeowTheme.spacingSM) {
            Text("L\(result.startLine)-\(result.endLine)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(mutedColor)
            if let source = result.source {
                Text(source)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(mutedColor)
            }
        }
    }

    // MARK: - Colors

    private var surfaceColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.surface : MeowTheme.Light.surface
    }

    private var borderColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.border : MeowTheme.Light.border
    }

    private var primaryColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.textPrimary : MeowTheme.Light.textPrimary
    }

    private var mutedColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.textMuted : MeowTheme.Light.textMuted
    }
}
