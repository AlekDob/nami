import SwiftUI

struct TerminalBox<Content: View>: View {
    let title: String?
    let content: () -> Content

    @Environment(\.colorScheme) private var colorScheme

    init(title: String? = nil, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title { titleRow(title) }
            content()
                .padding(.horizontal, MeowTheme.spacingMD)
                .padding(.bottom, MeowTheme.spacingMD)
                .padding(.top, title == nil ? MeowTheme.spacingMD : 0)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(colorScheme == .dark ? MeowTheme.Dark.surface : MeowTheme.Light.surface)
        .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerMD, style: .continuous))
    }

    private func titleRow(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
            .padding(.horizontal, MeowTheme.spacingMD)
            .padding(.top, MeowTheme.spacingMD)
            .padding(.bottom, MeowTheme.spacingSM)
    }
}
