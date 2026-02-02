import SwiftUI

struct CreateJobSheet: View {
    @Bindable var viewModel: JobsViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MeowTheme.spacingMD) {
                    headerIcon
                    nameField
                    cronField
                    taskField
                    togglesSection
                    if let error = viewModel.errorMessage { errorLabel(error) }
                }
                .padding(MeowTheme.spacingMD)
            }
            .background(bgColor)
            .navigationTitle("New Job")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbarItems }
        }
    }

    private var headerIcon: some View {
        ASCIICatView(mood: .happy, size: .medium)
            .padding(.top, MeowTheme.spacingSM)
    }

    private var nameField: some View {
        formField(label: "Name", placeholder: "Daily standup reminder", text: $viewModel.newJobName)
    }

    private var cronField: some View {
        VStack(alignment: .leading, spacing: MeowTheme.spacingXS) {
            Text("CRON")
                .font(.subheadline)
                .foregroundColor(secondaryColor)
            TextField("0 9 * * 1-5", text: $viewModel.newJobCron)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.plain)
                .glassInput()
            Text("min hour day month weekday")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(mutedColor)
        }
    }

    private var taskField: some View {
        VStack(alignment: .leading, spacing: MeowTheme.spacingXS) {
            Text("Task")
                .font(.subheadline)
                .foregroundColor(secondaryColor)
            TextField("What should meow do?", text: $viewModel.newJobTask, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.plain)
                .glassInput()
        }
    }

    private var togglesSection: some View {
        VStack(spacing: MeowTheme.spacingSM) {
            toggleRow(label: "Repeat", isOn: $viewModel.newJobRepeat, color: MeowTheme.accent)
            toggleRow(label: "Notify", isOn: $viewModel.newJobNotify, color: MeowTheme.yellow)
        }
    }

    private func toggleRow(label: String, isOn: Binding<Bool>, color: Color) -> some View {
        HStack {
            Text(label)
                .foregroundColor(primaryColor)
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(SwitchToggleStyle(tint: color))
                .labelsHidden()
        }
        .padding(MeowTheme.spacingSM + 4)
        .background(surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerRadiusSM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MeowTheme.cornerRadiusSM, style: .continuous)
                .stroke(borderColor, lineWidth: 1)
        )
    }

    private func errorLabel(_ message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundColor(MeowTheme.red)
    }

    private func formField(label: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: MeowTheme.spacingXS) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(secondaryColor)
            TextField(placeholder, text: text)
                .textFieldStyle(.plain)
                .glassInput()
        }
    }

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
                .foregroundColor(secondaryColor)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Create") { viewModel.createJob() }
                .foregroundColor(MeowTheme.accent)
                .disabled(!viewModel.canCreate)
        }
    }

    // MARK: - Colors

    private var bgColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.background : MeowTheme.Light.background
    }

    private var surfaceColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.surface : MeowTheme.Light.surface
    }

    private var borderColor: Color {
        colorScheme == .dark ? MeowTheme.Dark.border : MeowTheme.Light.border
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
