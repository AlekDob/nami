import SwiftUI

struct StatusPill: View {
    let status: ConnectionStatus

    @Environment(\.colorScheme) private var colorScheme

    enum ConnectionStatus: Sendable {
        case connected, disconnected, connecting

        var label: String {
            switch self {
            case .connected:    return "online"
            case .disconnected: return "offline"
            case .connecting:   return "connecting"
            }
        }

        var color: Color {
            switch self {
            case .connected:    return MeowTheme.green
            case .disconnected: return MeowTheme.red
            case .connecting:   return MeowTheme.yellow
            }
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)
            Text(status.label)
                .font(MeowTheme.monoSmall)
                .foregroundColor(colorScheme == .dark ? MeowTheme.Dark.textSecondary : MeowTheme.Light.textSecondary)
        }
    }
}
