import Foundation

@MainActor
@Observable
final class SoulViewModel {
    var content = ""
    var isLoading = false
    var isSaving = false
    var errorMessage: String?
    var saveSuccess = false
    var isEditing = false

    private let apiClient: MeowAPIClient

    init(apiClient: MeowAPIClient) {
        self.apiClient = apiClient
    }

    func loadSoul() {
        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let response = try await apiClient.fetchSoul()
                self.content = response.content
                self.isLoading = false
            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func saveSoul() {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            errorMessage = "Soul content cannot be empty"
            return
        }

        isSaving = true
        errorMessage = nil
        saveSuccess = false

        Task { @MainActor in
            do {
                let response = try await apiClient.updateSoul(content: trimmed)
                self.content = response.content
                self.isSaving = false
                self.saveSuccess = true
                self.isEditing = false
                scheduleDismissSaveSuccess()
            } catch {
                self.isSaving = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func toggleEditing() {
        isEditing.toggle()
    }

    private func scheduleDismissSaveSuccess() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            self.saveSuccess = false
        }
    }
}
