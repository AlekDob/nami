import SwiftUI

struct GlowButton: View {
    let title: String
    let icon: String?
    let color: Color
    let gradient: LinearGradient?
    let action: () -> Void

    init(
        _ title: String,
        icon: String? = nil,
        color: Color = MeowTheme.accent,
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
                        .font(.system(size: 13, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
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

    init(_ icon: String, color: Color = MeowTheme.accent, action: @escaping () -> Void) {
        self.icon = icon
        self.color = color
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(colorScheme == .dark ? MeowTheme.Dark.surface : MeowTheme.Light.surface)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(
                        colorScheme == .dark ? MeowTheme.Dark.border : MeowTheme.Light.border,
                        lineWidth: 1
                    )
                )
        }
        .buttonStyle(.plain)
    }
}
