import SwiftUI

struct JobRow: View {
    let job: Job
    let onToggle: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(spacing: MeowTheme.spacingSM) {
            statusIndicator
            jobInfo
            Spacer()
            toggleSwitch
        }
        .padding(MeowTheme.spacingSM + 4)
        .background(surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerSM, style: .continuous))
    }

    private var statusIndicator: some View {
        Circle()
            .fill(job.enabled ? MeowTheme.green : mutedColor)
            .frame(width: 8, height: 8)
    }

    private var jobInfo: some View {
        VStack(alignment: .leading, spacing: MeowTheme.spacingXS) {
            Text(job.name)
                .font(.headline)
                .foregroundColor(primaryColor)
            Text(job.cron)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(secondaryColor)
            Text(job.task)
                .font(.subheadline)
                .foregroundColor(secondaryColor)
                .lineLimit(2)
            if let lastRun = job.lastRun {
                Text("Last: \(lastRun)")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(mutedColor)
            }
        }
    }

    private var toggleSwitch: some View {
        Toggle("", isOn: .constant(job.enabled))
            .toggleStyle(SwitchToggleStyle(tint: MeowTheme.green))
            .labelsHidden()
            .onTapGesture { onToggle() }
    }

    // MARK: - Colors

    private var surfaceColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.surface : MeowTheme.Light.surface
    }

    private var primaryColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.textPrimary : MeowTheme.Light.textPrimary
    }

    private var secondaryColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.textSecondary : MeowTheme.Light.textSecondary
    }

    private var mutedColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.textMuted : MeowTheme.Light.textMuted
    }
}
