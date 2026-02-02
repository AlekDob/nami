import Foundation

enum ShareAPIError: Error {
    case notConfigured
    case invalidURL
    case serverError(Int)
}

struct ShareAPIClient: Sendable {
    let baseURL: String
    let apiKey: String

    func sendToMeow(message: String) async throws {
        guard !baseURL.isEmpty, !apiKey.isEmpty else {
            throw ShareAPIError.notConfigured
        }
        let trimmed = baseURL.trimmingCharacters(
            in: CharacterSet(charactersIn: "/")
        )
        guard let url = URL(string: "\(trimmed)/api/chat") else {
            throw ShareAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(
            "Bearer \(apiKey)",
            forHTTPHeaderField: "Authorization"
        )
        request.setValue(
            "application/json",
            forHTTPHeaderField: "Content-Type"
        )
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "messages": [["role": "user", "content": message]]
        ]
        request.httpBody = try JSONSerialization.data(
            withJSONObject: body
        )

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw ShareAPIError.serverError(status)
        }
    }
}
