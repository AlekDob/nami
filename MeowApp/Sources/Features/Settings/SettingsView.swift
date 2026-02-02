import SwiftUI

struct SettingsView: View {
    @Bindable var viewModel: SettingsViewModel
    let wsManager: WebSocketManager

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: MeowTheme.spacingMD) {
                    connectionSection
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
                    GlowButton("Test", icon: "bolt.fill", color: MeowTheme.accent) {
                        viewModel.testConnection()
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
                        .tint(MeowTheme.accent)
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
                Text("Current: \(viewModel.currentModel)")
                    .font(.subheadline)
                    .foregroundColor(MeowTheme.accent)
                if !viewModel.availableModels.isEmpty {
                    modelsText
                }
                modelInput
            }
        }
    }

    private var modelsText: some View {
        Text(viewModel.availableModels)
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(secondaryColor)
            .textSelection(.enabled)
    }

    @State private var modelIdInput = ""

    private var modelInput: some View {
        HStack(spacing: MeowTheme.spacingSM) {
            TextField("model-id", text: $modelIdInput)
                .font(.system(.caption, design: .monospaced))
                .textFieldStyle(.plain)
                .glassInput()
            GlowButton("Set", icon: "arrow.right", color: MeowTheme.yellow) {
                viewModel.changeModel(to: modelIdInput)
            }
        }
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
                .foregroundColor(MeowTheme.accent)
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
                .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerRadiusSM, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: MeowTheme.cornerRadiusSM, style: .continuous)
                        .stroke(borderColor, lineWidth: 1)
                )
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
        .clipShape(RoundedRectangle(cornerRadius: MeowTheme.cornerRadiusSM, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: MeowTheme.cornerRadiusSM, style: .continuous)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
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
