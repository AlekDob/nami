import Foundation

@MainActor
@Observable
final class JobsViewModel {
    var jobs: [Job] = []
    var isLoading = false
    var errorMessage: String?
    var showCreateSheet = false

    // Create form fields
    var newJobName = ""
    var newJobCron = ""
    var newJobTask = ""
    var newJobRepeat = true
    var newJobNotify = true
    var isCreating = false

    private let apiClient: MeowAPIClient

    init(apiClient: MeowAPIClient) {
        self.apiClient = apiClient
    }

    func loadJobs() {
        isLoading = true
        errorMessage = nil

        Task { @MainActor in
            do {
                let response = try await apiClient.fetchJobs()
                self.jobs = response.jobs
                self.isLoading = false
            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func toggleJob(_ job: Job) {
        Task { @MainActor in
            do {
                let updated = try await apiClient.toggleJob(id: job.id)
                updateJobInList(updated)
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func deleteJob(_ job: Job) {
        Task { @MainActor in
            do {
                _ = try await apiClient.deleteJob(id: job.id)
                self.jobs.removeAll { $0.id == job.id }
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func createJob() {
        let trimmedName = newJobName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCron = newJobCron.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTask = newJobTask.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, !trimmedCron.isEmpty, !trimmedTask.isEmpty else {
            errorMessage = "All fields are required"
            return
        }

        isCreating = true

        let request = CreateJobRequest(
            name: trimmedName,
            cron: trimmedCron,
            task: trimmedTask,
            repeat: newJobRepeat,
            notify: newJobNotify
        )

        Task { @MainActor in
            do {
                let job = try await apiClient.createJob(request)
                self.jobs.append(job)
                resetCreateForm()
                self.showCreateSheet = false
            } catch {
                self.isCreating = false
                self.errorMessage = error.localizedDescription
            }
        }
    }

    var canCreate: Bool {
        !newJobName.isEmpty && !newJobCron.isEmpty && !newJobTask.isEmpty && !isCreating
    }

    // MARK: - Private

    private func updateJobInList(_ updated: Job) {
        if let index = jobs.firstIndex(where: { $0.id == updated.id }) {
            jobs[index] = updated
        }
    }

    private func resetCreateForm() {
        newJobName = ""
        newJobCron = ""
        newJobTask = ""
        newJobRepeat = true
        newJobNotify = true
        isCreating = false
    }
}
