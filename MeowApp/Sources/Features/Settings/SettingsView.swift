import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    let wsManager: WebSocketManager
    var onMenuTap: (() -> Void)?

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MeowTheme.spacingMD) {
                    connectionSection
                    elevenLabsSection
                    serverSection
                    modelSection
                    securitySection
                    statusSection
                    banners
                }
                .padding(MeowTheme.spacingMD)
            }
            .background(bgColor)
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar { menuButton }
            .onAppear { viewModel.loadServerStatus(); viewModel.loadModels() }
        }
    }

    // MARK: - Connection

    private var connectionSection: some View {
        TerminalBox(title: "Connection") {
            VStack(spacing: MeowTheme.spacingSM) {
                formField(label: "Server URL", placeholder: "http://1.2.3.4:3000", text: $viewModel.serverURL)
                formField(label: "API Key", placeholder: "your-api-key", text: $viewModel.apiKey, isSecure: true)
                HStack(spacing: MeowTheme.spacingSM) {
                    GlowButton("Save", icon: "checkmark", color: MeowTheme.green) {
                        viewModel.saveConfiguration()
                    }
                    GlowButton("Test", icon: "bolt.fill") {
                        viewModel.testConnection()
                    }
                }
            }
        }
    }

    // MARK: - ElevenLabs TTS

    private var elevenLabsSection: some View {
        TerminalBox(title: "Voice (ElevenLabs)") {
            VStack(spacing: MeowTheme.spacingSM) {
                formField(label: "ElevenLabs API Key", placeholder: "sk_...", text: $viewModel.elevenLabsAPIKey, isSecure: true)
                HStack {
                    Text("Premium TTS")
                        .font(.subheadline)
                        .foregroundColor(secondaryColor)
                    Spacer()
                    if viewModel.elevenLabsAPIKey.isEmpty {
                        Text("Not configured")
                            .font(.caption)
                            .foregroundColor(mutedColor)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(MeowTheme.green)
                    }
                }
            }
        }
    }

    // MARK: - Server

    private var serverSection: some View {
        TerminalBox(title: "Server") {
            VStack(spacing: MeowTheme.spacingSM) {
                HStack {
                    StatusPill(status: wsManager.isConnected ? .connected : .disconnected)
                    Spacer()
                    wsToggle
                }
                if viewModel.isLoadingStatus {
                    ProgressView()
                        .tint(.primary)
                } else if let status = viewModel.serverStatus {
                    serverStatusRows(status)
                }
            }
        }
    }

    private var wsToggle: some View {
        Button {
            if wsManager.isConnected {
                viewModel.disconnectWebSocket()
            } else {
                viewModel.connectWebSocket()
            }
        } label: {
            Text(wsManager.isConnected ? "Disconnect" : "Connect WS")
                .font(.subheadline)
                .foregroundColor(wsManager.isConnected ? MeowTheme.red : MeowTheme.green)
        }
        .buttonStyle(.plain)
    }

    private func serverStatusRows(_ status: ServerStatus) -> some View {
        VStack(alignment: .leading, spacing: MeowTheme.spacingXS) {
            statusRow("Model", value: status.model ?? "N/A")
            if let uptime = status.uptime {
                statusRow("Uptime", value: formatUptime(uptime))
            }
            if let mem = status.memory {
                statusRow("Memory", value: formatMemory(mem))
            }
        }
    }

    private func statusRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(secondaryColor)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(primaryColor)
        }
    }

    // MARK: - Model

    private var modelSection: some View {
        TerminalBox(title: "Model") {
            VStack(alignment: .leading, spacing: MeowTheme.spacingSM) {
                if !viewModel.modelList.isEmpty {
                    modelPicker
                } else {
                    Text("Current: \(viewModel.currentModel)")
                        .font(.subheadline)
                        .foregroundColor(primaryColor)
                    if !viewModel.availableModels.isEmpty {
                        Text(viewModel.availableModels)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(secondaryColor)
                            .textSelection(.enabled)
                    }
                }
                if viewModel.isChangingModel {
                    ProgressView()
                        .tint(.primary)
                }
            }
        }
    }

    private var modelPicker: some View {
        VStack(alignment: .leading, spacing: MeowTheme.spacingSM) {
            ForEach(["fast", "smart", "pro"], id: \.self) { preset in
                let models = viewModel.modelList.filter { $0.preset == preset }
                if !models.isEmpty {
                    Text(preset.uppercased())
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(mutedColor)
                    ForEach(models) { model in
                        modelRow(model)
                    }
                }
            }
        }
    }

    private func modelRow(_ model: ModelInfo) -> some View {
        Button {
            guard !model.current else { return }
            viewModel.changeModel(to: model.id)
        } label: {
            HStack(spacing: MeowTheme.spacingSM) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.label)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundColor(model.current ? primaryColor : secondaryColor)
                    HStack(spacing: 6) {
                        if model.vision {
                            badge("vision", color: MeowTheme.green)
                        }
                        if model.toolUse {
                            badge("tools", color: secondaryColor)
                        }
                    }
                }
                Spacer()
                if model.current {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(MeowTheme.green)
                        .font(.system(size: 16))
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(model.current ? surfaceHoverColor : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 9, design: .monospaced))
            .foregroundColor(color)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
    }

    // MARK: - Security

    private var securitySection: some View {
        TerminalBox(title: "Security") {
            if viewModel.isBiometricAvailable {
                biometricToggle
            } else {
                Text("Biometric auth not available")
                    .font(.subheadline)
                    .foregroundColor(mutedColor)
            }
        }
    }

    private var biometricToggle: some View {
        HStack {
            Image(systemName: "faceid")
                .foregroundColor(primaryColor)
            Text("Face ID / Touch ID")
                .foregroundColor(primaryColor)
            Spacer()
            Toggle("", isOn: .init(
                get: { viewModel.biometricEnabled },
                set: { _ in viewModel.toggleBiometric() }
            ))
            .toggleStyle(SwitchToggleStyle(tint: MeowTheme.green))
            .labelsHidden()
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        Group {
            if let error = wsManager.lastError {
                HStack(spacing: MeowTheme.spacingSM) {
                    Image(systemName: "wifi.slash")
                        .foregroundColor(MeowTheme.red)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(MeowTheme.red)
                }
                .padding(MeowTheme.spacingSM + 2)
                .background(surfaceColor)
                .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerSM, style: .continuous))
            }
        }
    }

    private var banners: some View {
        VStack(spacing: MeowTheme.spacingSM) {
            if let error = viewModel.errorMessage {
                bannerView(error, color: MeowTheme.red, icon: "exclamationmark.triangle.fill")
            }
            if let success = viewModel.successMessage {
                bannerView(success, color: MeowTheme.green, icon: "checkmark.circle.fill")
            }
        }
    }

    private func bannerView(_ message: String, color: Color, icon: String) -> some View {
        HStack(spacing: MeowTheme.spacingSM) {
            Image(systemName: icon).foregroundColor(color)
            Text(message).font(.subheadline).foregroundColor(color)
        }
        .padding(MeowTheme.spacingSM + 2)
        .background(surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerSM, style: .continuous))
    }

    // MARK: - Form helpers

    private func formField(label: String, placeholder: String, text: Binding<String>, isSecure: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: MeowTheme.spacingXS) {
            Text(label)
                .font(.subheadline)
                .foregroundColor(secondaryColor)
            Group {
                if isSecure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .textFieldStyle(.plain)
            .glassInput()
        }
    }

    // MARK: - Helpers

    private func formatUptime(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }

    private func formatMemory(_ mem: ServerMemory) -> String {
        let rss = (mem.rss ?? 0) / 1024 / 1024
        return "\(rss) MB"
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

    // MARK: - Colors

    private var bgColor: Color { colorScheme == .dark ? MeowTheme.Dark.background : MeowTheme.Light.background }
    private var primaryColor: Color { colorScheme == .dark ? MeowTheme.Dark.textPrimary : MeowTheme.Light.textPrimary }
    private var secondaryColor: Color { colorScheme == .dark ? MeowTheme.Dark.textSecondary : MeowTheme.Light.textSecondary }
    private var mutedColor: Color { colorScheme == .dark ? MeowTheme.Dark.textMuted : MeowTheme.Light.textMuted }
    private var surfaceColor: Color { colorScheme == .dark ? MeowTheme.Dark.surface : MeowTheme.Light.surface }
    private var surfaceHoverColor: Color { colorScheme == .dark ? MeowTheme.Dark.surfaceHover : MeowTheme.Light.surfaceHover }
}
