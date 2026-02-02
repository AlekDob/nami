import Foundation
import SwiftData

@MainActor
@Observable
final class MemoryViewModel {
    var searchQuery = ""
    var results: [MemoryResult] = []
    var isSearching = false
    var errorMessage: String?
    var selectedResult: MemoryResult?
    var fileContent: String?
    var isLoadingContent = false
    private var hasLoadedRecent = false

    private let apiClient: MeowAPIClient
    private var modelContext: ModelContext?

    init(apiClient: MeowAPIClient) {
        self.apiClient = apiClient
    }

    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }

    func loadRecentIfNeeded() {
        guard !hasLoadedRecent, results.isEmpty, searchQuery.isEmpty else { return }
        hasLoadedRecent = true
        isSearching = true

        Task { @MainActor in
            do {
                let response = try await apiClient.fetchRecentMemories(limit: 10)
                if self.searchQuery.isEmpty {
                    self.results = response.results
                }
                self.isSearching = false
            } catch {
                self.isSearching = false
            }
        }
    }

    func search() {
        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSearching = true
        errorMessage = nil

        Task { @MainActor in
            do {
                print("[Memory] Searching for: \(trimmed)")
                let response = try await apiClient.searchMemory(query: trimmed)
                print("[Memory] Got \(response.results.count) results")
                self.results = response.results
                cacheResults(query: trimmed, results: response.results)
                self.isSearching = false
            } catch {
                print("[Memory] Search error: \(error)")
                self.isSearching = false
                self.errorMessage = error.localizedDescription
                loadCachedResults(query: trimmed)
            }
        }
    }

    func loadFileContent(result: MemoryResult) {
        selectedResult = result
        isLoadingContent = true
        fileContent = nil

        Task { @MainActor in
            do {
                let lineCount = result.endLine - result.startLine + 40
                let response = try await apiClient.fetchMemoryLines(
                    path: result.path,
                    from: max(0, result.startLine - 10),
                    count: lineCount
                )
                self.fileContent = response.text
                cacheFileContent(path: result.path, content: response.text)
                self.isLoadingContent = false
            } catch {
                self.isLoadingContent = false
                self.errorMessage = error.localizedDescription
                loadCachedFileContent(path: result.path)
            }
        }
    }

    func clearSearch() {
        searchQuery = ""
        results = []
        errorMessage = nil
        selectedResult = nil
        fileContent = nil
    }

    // MARK: - Cache (SwiftData)

    private func cacheResults(query: String, results: [MemoryResult]) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard let context = self?.modelContext else { return }
            for result in results {
                let entry = CachedMemoryEntry.fromAPIResult(query: query, result: result)
                context.insert(entry)
            }
            try? context.save()
        }
    }

    private func loadCachedResults(query: String) {
        guard let context = modelContext else { return }
        let predicate = #Predicate<CachedMemoryEntry> { entry in
            entry.query == query
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        guard let cached = try? context.fetch(descriptor) else { return }
        results = cached.map { $0.toMemoryResult() }
    }

    private func cacheFileContent(path: String, content: String) {
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            guard let context = self?.modelContext else { return }
            let entry = CachedFileContent(path: path, content: content)
            context.insert(entry)
            try? context.save()
        }
    }

    private func loadCachedFileContent(path: String) {
        guard let context = modelContext else { return }
        let predicate = #Predicate<CachedFileContent> { entry in
            entry.path == path
        }
        let descriptor = FetchDescriptor(predicate: predicate)
        guard let cached = try? context.fetch(descriptor), let first = cached.first else { return }
        fileContent = first.content
    }
}
