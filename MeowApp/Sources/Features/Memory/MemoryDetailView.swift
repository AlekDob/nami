import SwiftUI

struct MemoryDetailView: View {
    let result: MemoryResult
    let content: String?
    let isLoading: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: MeowTheme.spacingMD) {
                headerSection
                contentSection
            }
            .padding(MeowTheme.spacingMD)
        }
        .background(bgColor)
        .navigationTitle(fileName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private var fileName: String {
        result.path.components(separatedBy: "/").last ?? result.path
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: MeowTheme.spacingSM) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(secondaryColor)
                Text(result.path)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(secondaryColor)
            }
            HStack(spacing: MeowTheme.spacingSM) {
                metadataChip("L\(result.startLine)-\(result.endLine)")
                metadataChip(String(format: "%.0f%% match", result.score * 100))
                if let source = result.source {
                    metadataChip(source)
                }
            }
        }
    }

    private func metadataChip(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(secondaryColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(surfaceColor)
            .clipShape(Capsule())
    }

    private var contentSection: some View {
        Group {
            if isLoading {
                loadingView
            } else if let content {
                fileContentView(content)
            } else {
                snippetFallback
            }
        }
    }

    private var loadingView: some View {
        TerminalBox(title: fileName) {
            HStack {
                ProgressView()
                    .tint(.primary)
                Text("Loading...")
                    .font(.subheadline)
                    .foregroundColor(secondaryColor)
            }
        }
    }

    private func fileContentView(_ content: String) -> some View {
        TerminalBox(title: fileName) {
            Text(content)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(primaryColor)
                .textSelection(.enabled)
        }
    }

    private var snippetFallback: some View {
        TerminalBox(title: "snippet") {
            Text(result.snippet)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(primaryColor)
                .textSelection(.enabled)
        }
    }

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

    private var secondaryColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.textSecondary : MeowTheme.Light.textSecondary
    }
}
