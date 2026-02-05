import Foundation
import Observation

@MainActor
@Observable
final class OSViewModel {
    private let api: MeowAPIClient
    private let serverBaseURL: String

    var creations: [Creation] = []
    var isLoading = false
    var errorMessage: String?
    var selectedCreation: Creation?
    var previewHTML: String?
    var showPreview = false

    init(api: MeowAPIClient, baseURL: String) {
        self.api = api
        self.serverBaseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    func loadCreations() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let response: CreationsResponse = try await api.fetchCreations()
                self.creations = response.creations
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    func loadPreview(for creation: Creation) {
        selectedCreation = creation
        previewHTML = nil  // Reset
        showPreview = true  // Show sheet immediately with loading state

        Task {
            do {
                print("[OSViewModel] Fetching preview for: \(creation.id)")
                let html = try await api.fetchCreationPreview(id: creation.id)
                print("[OSViewModel] Got HTML: \(html.prefix(100))...")
                self.previewHTML = html
            } catch {
                print("[OSViewModel] Preview error: \(error)")
                self.errorMessage = "Preview not available: \(error.localizedDescription)"
                self.previewHTML = nil
            }
        }
    }

    func deleteCreation(_ creation: Creation) {
        Task {
            do {
                _ = try await api.deleteCreation(id: creation.id)
                self.creations.removeAll { $0.id == creation.id }
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    var apps: [Creation] {
        creations.filter { $0.type == .app }
    }

    var documents: [Creation] {
        creations.filter { $0.type == .document }
    }

    var scripts: [Creation] {
        creations.filter { $0.type == .script }
    }

    func getPreviewURL(for creation: Creation) -> String {
        "\(serverBaseURL)/api/creations/\(creation.id)/preview"
    }
}
