import SwiftUI

struct CreationBanner: View {
    let info: CreationInfo
    let onTap: () -> Void
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: MeowTheme.spacingMD) {
                Image(systemName: info.icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("New \(typeLabel)")
                        .font(.caption)
                        .foregroundColor(secondaryColor)
                    Text(info.name)
                        .font(.body.weight(.medium))
                        .foregroundColor(primaryColor)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("View")
                        .font(.subheadline.weight(.medium))
                    Image(systemName: "arrow.right")
                        .font(.caption)
                }
                .foregroundColor(MeowTheme.green)
            }
            .padding(MeowTheme.spacingMD)
            .background(surfaceColor)
            .overlay(
                RoundedRectangle(cornerRadius: MeowTheme.cornerMD, style: .continuous)
                    .stroke(MeowTheme.green.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerMD, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var typeLabel: String {
        switch info.type {
        case "app": return "App"
        case "document": return "Document"
        case "script": return "Script"
        default: return "Creation"
        }
    }

    private var iconColor: Color {
        switch info.type {
        case "app": return MeowTheme.green
        case "document": return MeowTheme.purple
        case "script": return MeowTheme.yellow
        default: return MeowTheme.green
        }
    }

    private var primaryColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.textPrimary : MeowTheme.Light.textPrimary
    }

    private var secondaryColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.textSecondary : MeowTheme.Light.textSecondary
    }

    private var surfaceColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.surface : MeowTheme.Light.surface
    }
}
