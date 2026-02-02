import Foundation

actor MeowAPIClient {
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    private var baseURL: String
    private var apiKey: String

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
        self.baseURL = ""
        self.apiKey = ""
    }

    func configure(baseURL: String, apiKey: String) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.apiKey = apiKey
    }

    // MARK: - Chat

    func sendChat(messages: [ChatMessage]) async throws -> ChatResponse {
        let body = ChatRequest(messages: messages)
        return try await post("/api/chat", body: body)
    }

    // MARK: - Status

    func fetchStatus() async throws -> ServerStatus {
        try await get("/api/status")
    }

    // MARK: - Models

    func fetchModels() async throws -> ModelsResponse {
        try await get("/api/models")
    }

    func setModel(id: String) async throws -> SetModelResponse {
        let body = SetModelRequest(id: id)
        return try await put("/api/model", body: body)
    }

    // MARK: - Memory

    func searchMemory(query: String) async throws -> MemorySearchResponse {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return try await get("/api/memory/search?q=\(encoded)")
    }

    func fetchMemoryLines(path: String, from: Int, count: Int) async throws -> MemoryLinesResponse {
        let encodedPath = path.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? path
        return try await get("/api/memory/lines?path=\(encodedPath)&from=\(from)&count=\(count)")
    }

    func fetchRecentMemories(limit: Int = 10) async throws -> MemoryRecentResponse {
        try await get("/api/memory/recent?limit=\(limit)")
    }

    // MARK: - Jobs

    func fetchJobs() async throws -> JobsListResponse {
        try await get("/api/jobs")
    }

    func createJob(_ request: CreateJobRequest) async throws -> Job {
        try await post("/api/jobs", body: request)
    }

    func deleteJob(id: String) async throws -> DeleteJobResponse {
        try await delete("/api/jobs/\(id)")
    }

    func toggleJob(id: String) async throws -> Job {
        try await patch("/api/jobs/\(id)/toggle")
    }

    // MARK: - Soul

    func fetchSoul() async throws -> SoulResponse {
        try await get("/api/soul")
    }

    func updateSoul(content: String) async throws -> SoulResponse {
        let body = SoulUpdateRequest(content: content)
        return try await put("/api/soul", body: body)
    }

    // MARK: - Device Registration

    func registerDevice(token: String) async throws -> RegisterDeviceResponse {
        let body = RegisterDeviceRequest(token: token)
        return try await post("/api/register-device", body: body)
    }

    func unregisterDevice(token: String) async throws -> RegisterDeviceResponse {
        let body = RegisterDeviceRequest(token: token)
        return try await deleteWithBody("/api/register-device", body: body)
    }

    // MARK: - Health

    func checkHealth() async throws -> HealthResponse {
        try await getNoAuth("/api/health")
    }

    // MARK: - Private HTTP Methods

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let request = try buildRequest(path: path, method: "GET")
        return try await execute(request)
    }

    private func getNoAuth<T: Decodable>(_ path: String) async throws -> T {
        var request = URLRequest(url: try buildURL(path))
        request.httpMethod = "GET"
        return try await execute(request)
    }

    private func post<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        var request = try buildRequest(path: path, method: "POST")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }

    private func put<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        var request = try buildRequest(path: path, method: "PUT")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }

    private func delete<T: Decodable>(_ path: String) async throws -> T {
        let request = try buildRequest(path: path, method: "DELETE")
        return try await execute(request)
    }

    private func deleteWithBody<B: Encodable, T: Decodable>(_ path: String, body: B) async throws -> T {
        var request = try buildRequest(path: path, method: "DELETE")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }

    private func patch<T: Decodable>(_ path: String) async throws -> T {
        let request = try buildRequest(path: path, method: "PATCH")
        return try await execute(request)
    }

    private func buildURL(_ path: String) throws -> URL {
        guard let url = URL(string: baseURL + path) else {
            throw APIError.invalidURL
        }
        return url
    }

    private func buildRequest(path: String, method: String) throws -> URLRequest {
        var request = URLRequest(url: try buildURL(path))
        request.httpMethod = method
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        return request
    }

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        guard (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown"
            throw APIError.httpError(status: http.statusCode, body: body)
        }
        return try decoder.decode(T.self, from: data)
    }
}

// MARK: - Supporting Types

struct JobsListResponse: Codable {
    let jobs: [Job]
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(status: Int, body: String)
    case notConfigured

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response"
        case .httpError(let status, let body): return "HTTP \(status): \(body)"
        case .notConfigured: return "API not configured"
        }
    }
}
