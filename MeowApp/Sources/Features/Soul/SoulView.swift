import SwiftUI

struct SoulView: View {
    @Bindable var viewModel: SoulViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MeowTheme.spacingMD) {
                    headerSection
                    if viewModel.isLoading { loadingSection }
                    else { contentSection }
                    if let error = viewModel.errorMessage { errorSection(error) }
                    if viewModel.saveSuccess { successBanner }
                }
                .padding(MeowTheme.spacingMD)
            }
            .background(bgColor)
            .navigationTitle("Soul")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar { toolbarItems }
            .onAppear { viewModel.loadSoul() }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: MeowTheme.spacingSM) {
            ASCIICatView(mood: .happy, size: .large)
            Text("Personality & Behavior")
                .font(.headline)
                .foregroundColor(secondaryColor)
        }
    }

    // MARK: - Content

    private var loadingSection: some View {
        TerminalBox(title: "soul.md") {
            HStack {
                ProgressView()
                    .tint(MeowTheme.accent)
                Text("Loading personality...")
                    .font(.subheadline)
                    .foregroundColor(secondaryColor)
            }
        }
    }

    private var contentSection: some View {
        TerminalBox(title: "soul.md") {
            if viewModel.isEditing {
                editableContent
            } else {
                readOnlyContent
            }
        }
    }

    private var editableContent: some View {
        TextEditor(text: $viewModel.content)
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(primaryColor)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 300)
    }

    private var readOnlyContent: some View {
        Text(viewModel.content)
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(primaryColor)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Banners

    private func errorSection(_ message: String) -> some View {
        HStack(spacing: MeowTheme.spacingSM) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(MeowTheme.red)
            Text(message)
                .font(.subheadline)
                .foregroundColor(MeowTheme.red)
        }
        .padding(MeowTheme.spacingSM + 2)
        .background(surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerRadiusSM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MeowTheme.cornerRadiusSM, style: .continuous)
                .stroke(MeowTheme.red.opacity(0.3), lineWidth: 1)
        )
    }

    private var successBanner: some View {
        HStack(spacing: MeowTheme.spacingSM) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(MeowTheme.green)
            Text("Soul saved successfully")
                .font(.subheadline)
                .foregroundColor(MeowTheme.green)
        }
        .padding(MeowTheme.spacingSM + 2)
        .background(surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerRadiusSM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MeowTheme.cornerRadiusSM, style: .continuous)
                .stroke(MeowTheme.green.opacity(0.3), lineWidth: 1)
        )
        .transition(.opacity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            if viewModel.isEditing {
                saveButton
            } else {
                editButton
            }
        }
    }

    private var editButton: some View {
        Button {
            viewModel.toggleEditing()
        } label: {
            Image(systemName: "pencil")
                .foregroundColor(MeowTheme.accent)
        }
    }

    private var saveButton: some View {
        Button {
            viewModel.saveSoul()
        } label: {
            if viewModel.isSaving {
                ProgressView()
                    .tint(MeowTheme.accent)
            } else {
                Image(systemName: "checkmark")
                    .foregroundColor(MeowTheme.green)
            }
        }
        .disabled(viewModel.isSaving)
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
