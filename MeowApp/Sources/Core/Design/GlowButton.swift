import SwiftUI

struct GlowButton: View {
    let title: String
    let icon: String?
    let color: Color
    let gradient: LinearGradient?
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    init(
        _ title: String,
        icon: String? = nil,
        color: Color = .primary,
        gradient: LinearGradient? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.gradient = gradient
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundColor(colorScheme == .dark ? MeowTheme.Dark.background : MeowTheme.Light.background)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerSM, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct GlowIconButton: View {
    let icon: String
    let color: Color
    let action: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    init(_ icon: String, color: Color = .primary, action: @escaping () -> Void) {
        self.icon = icon
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(color)
                .frame(width: 36, height: 36)
                .background(colorScheme == .dark ? MeowTheme.Dark.surface : MeowTheme.Light.surface)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
