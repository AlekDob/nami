import Foundation

@MainActor
@Observable
final class SettingsViewModel {
    var serverURL: String
    var apiKey: String
    var elevenLabsAPIKey: String = "" {
        didSet { SharedConfig.elevenLabsAPIKey = elevenLabsAPIKey }
    }
    var currentModel = ""
    var availableModels = ""
    var modelList: [ModelInfo] = []
    var isLoadingStatus = false
    var isChangingModel = false
    var serverStatus: ServerStatus?
    var errorMessage: String?
    var successMessage: String?
    var biometricEnabled: Bool

    private let authManager: AuthManager
    private let apiClient: MeowAPIClient
    private let wsManager: WebSocketManager

    init(authManager: AuthManager, apiClient: MeowAPIClient, wsManager: WebSocketManager) {
        self.authManager = authManager
        self.apiClient = apiClient
        self.wsManager = wsManager
        self.serverURL = authManager.serverURL
        self.apiKey = authManager.apiKey
        self.elevenLabsAPIKey = SharedConfig.elevenLabsAPIKey
        self.biometricEnabled = authManager.biometricEnabled
    }

    var isBiometricAvailable: Bool {
        authManager.isBiometricAvailable
    }

    var isConfigured: Bool {
        !serverURL.isEmpty && !apiKey.isEmpty
    }

    func saveConfiguration() {
        authManager.serverURL = serverURL
        authManager.apiKey = apiKey

        Task { await apiClient.configure(baseURL: serverURL, apiKey: apiKey) }
        wsManager.configure(baseURL: serverURL, apiKey: apiKey)
        wsManager.clearError()

        successMessage = "Configuration saved"
        scheduleDismissSuccess()
    }

    func toggleBiometric() {
        biometricEnabled.toggle()
        authManager.setBiometricEnabled(biometricEnabled)
    }

    func loadServerStatus() {
        isLoadingStatus = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let status = try await apiClient.fetchStatus()
                self.serverStatus = status
                self.currentModel = status.model ?? "unknown"
                self.isLoadingStatus = false
            } catch {
                self.isLoadingStatus = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func loadModels() {
        Task { @MainActor in
            do {
                let response = try await apiClient.fetchModelList()
                self.modelList = response.models
                if let current = response.models.first(where: { $0.current }) {
                    self.currentModel = current.id
                }
            } catch {
                // Fallback to text-based models endpoint
                if let response = try? await apiClient.fetchModels() {
                    self.availableModels = response.models
                }
            }
        }
    }

    func changeModel(to modelId: String) {
        isChangingModel = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let response = try await apiClient.setModel(id: modelId)
                self.currentModel = modelId
                // Update current flag in local list
                self.modelList = self.modelList.map { m in
                    ModelInfo(id: m.id, label: m.label, preset: m.preset, vision: m.vision, toolUse: m.toolUse, current: m.id == modelId)
                }
                self.successMessage = response.message
                self.isChangingModel = false
                scheduleDismissSuccess()
            } catch {
                self.isChangingModel = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func connectWebSocket() {
        wsManager.configure(baseURL: serverURL, apiKey: apiKey)
        wsManager.connect()
    }

    func disconnectWebSocket() {
        wsManager.disconnect()
    }

    func testConnection() {
        isLoadingStatus = true
        errorMessage = nil
        wsManager.clearError()

        Task { @MainActor in
            do {
                _ = try await apiClient.checkHealth()
                self.isLoadingStatus = false
                self.successMessage = "Connection successful"
                scheduleDismissSuccess()
                // Reload server status after successful test
                loadServerStatus()
                loadModels()
            } catch {
                self.isLoadingStatus = false
                self.errorMessage = "Connection failed: \(error.localizedDescription)"
            }
        }
    }

    private func scheduleDismissSuccess() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            self.successMessage = nil
        }
    }
}
