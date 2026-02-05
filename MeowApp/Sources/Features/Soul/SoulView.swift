import SwiftUI

struct SoulView: View {
    @Bindable var viewModel: SoulViewModel
    var onMenuTap: (() -> Void)?
    @Binding var namiProps: NamiProps
    let namiLevel: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MeowTheme.spacingMD) {
                    namiEditorSection
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
            .toolbar {
                menuButton
                toolbarItems
            }
            .onAppear { viewModel.loadSoul() }
        }
    }

    // MARK: - Nami Editor

    private var namiEditorSection: some View {
        TerminalBox(title: "nami.config") {
            VStack(spacing: MeowTheme.spacingMD) {
                // Preview
                NamiEntityView(
                    props: namiProps,
                    state: .idle,
                    level: namiLevel,
                    size: 120
                )

                // Name
                HStack {
                    Text("Name")
                        .font(.subheadline)
                        .foregroundColor(secondaryColor)
                    Spacer()
                    TextField("Name", text: $namiProps.name)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.plain)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                        .foregroundColor(primaryColor)
                }

                // Personality
                HStack {
                    Text("Personality")
                        .font(.subheadline)
                        .foregroundColor(secondaryColor)
                    Spacer()
                    Picker("", selection: $namiProps.personality) {
                        ForEach(NamiProps.Personality.allCases, id: \.self) { p in
                            Text(p.rawValue.capitalized).tag(p)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(primaryColor)
                }

                // Form Style
                HStack {
                    Text("Form")
                        .font(.subheadline)
                        .foregroundColor(secondaryColor)
                    Spacer()
                    Picker("", selection: $namiProps.formStyle) {
                        ForEach(NamiProps.FormStyle.allCases, id: \.self) { s in
                            Text(s.displayName).tag(s)
                        }
                    }
                    .pickerStyle(.menu)
                    .tint(primaryColor)
                }

                // Colors
                HStack(spacing: MeowTheme.spacingMD) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Primary")
                            .font(.caption)
                            .foregroundColor(secondaryColor)
                        ColorPicker("", selection: Binding(
                            get: { namiProps.dominantSwiftUIColor },
                            set: { namiProps.dominantColor = $0.toHex() }
                        ))
                        .labelsHidden()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Secondary")
                            .font(.caption)
                            .foregroundColor(secondaryColor)
                        ColorPicker("", selection: Binding(
                            get: { namiProps.secondarySwiftUIColor },
                            set: { namiProps.secondaryColor = $0.toHex() }
                        ))
                        .labelsHidden()
                    }
                    Spacer()
                }

                // Level Progress
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Level \(namiLevel)")
                            .font(.subheadline.bold())
                            .foregroundColor(primaryColor)
                        Spacer()
                        Text(levelName)
                            .font(.caption)
                            .foregroundColor(MeowTheme.cyan)
                    }
                    ProgressView(value: levelProgress)
                        .tint(MeowTheme.cyan)
                }
            }
        }
        .onChange(of: namiProps) { _, newValue in
            newValue.save()
        }
    }

    private var levelName: String {
        switch namiLevel {
        case 1...2: return "Ripple"
        case 3...4: return "Surge"
        case 5...6: return "Current"
        case 7...8: return "Tsunami"
        case 9...10: return "Ocean"
        default: return "Ripple"
        }
    }

    private var levelProgress: Double {
        let xpForCurrent = Int(pow(Double(namiLevel), 2.5) * 100)
        let xpForNext = Int(pow(Double(namiLevel + 1), 2.5) * 100)
        return Double(xpForCurrent) / Double(xpForNext)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: MeowTheme.spacingSM) {
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
                    .tint(.primary)
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
        .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerSM, style: .continuous))
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
        .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerSM, style: .continuous))
        .transition(.opacity)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var menuButton: some ToolbarContent {
        ToolbarItem(placement: .navigation) {
            Button { onMenuTap?() } label: {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(primaryColor)
            }
        }
    }

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
                .foregroundColor(.primary)
        }
    }

    private var saveButton: some View {
        Button {
            viewModel.saveSoul()
        } label: {
            if viewModel.isSaving {
                ProgressView()
                    .tint(.primary)
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
