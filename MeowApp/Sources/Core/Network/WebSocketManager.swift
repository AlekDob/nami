import Foundation

@MainActor
@Observable
final class WebSocketManager {
    var isConnected = false
    var lastError: String?

    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession
    private var pingTimer: Timer?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    private var baseURL = ""
    private var apiKey = ""

    var onMessage: ((WSIncoming) -> Void)?

    init() {
        self.session = URLSession(configuration: .default)
    }

    func configure(baseURL: String, apiKey: String) {
        self.baseURL = baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.apiKey = apiKey
    }

    func connect() {
        guard !baseURL.isEmpty, !apiKey.isEmpty else { return }
        disconnect()

        let wsURL = buildWebSocketURL()
        guard let url = URL(string: wsURL) else { return }

        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()
        isConnected = true
        reconnectAttempts = 0
        lastError = nil

        startListening()
        startPingTimer()
    }

    func disconnect() {
        stopPingTimer()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    func sendChat(messages: [ChatMessage]) {
        let outgoing = WSOutgoing.chat(messages: messages)
        sendMessage(outgoing)
    }

    func sendPing() {
        sendMessage(WSOutgoing.ping)
    }

    // MARK: - Private

    private func buildWebSocketURL() -> String {
        let wsBase = baseURL
            .replacingOccurrences(of: "https://", with: "wss://")
            .replacingOccurrences(of: "http://", with: "ws://")
        return "\(wsBase)/ws?key=\(apiKey)"
    }

    private func sendMessage(_ message: WSOutgoing) {
        guard let task = webSocketTask else { return }
        do {
            let data = try JSONEncoder().encode(message)
            let string = String(data: data, encoding: .utf8) ?? "{}"
            task.send(.string(string)) { [weak self] error in
                if let error {
                    Task { @MainActor in self?.handleError(error) }
                }
            }
        } catch {
            handleError(error)
        }
    }

    private func startListening() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let message):
                    self.handleReceivedMessage(message)
                    self.startListening()
                case .failure(let error):
                    self.handleDisconnect(error)
                }
            }
        }
    }

    private func handleReceivedMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .string(let text):
            data = Data(text.utf8)
        case .data(let d):
            data = d
        @unknown default:
            return
        }

        do {
            let incoming = try JSONDecoder().decode(WSIncoming.self, from: data)
            onMessage?(incoming)
        } catch {
            lastError = "Decode error: \(error.localizedDescription)"
        }
    }

    private func handleError(_ error: Error) {
        lastError = error.localizedDescription
    }

    private func handleDisconnect(_ error: Error) {
        isConnected = false
        lastError = error.localizedDescription
        attemptReconnect()
    }

    private func attemptReconnect() {
        guard reconnectAttempts < maxReconnectAttempts else { return }
        reconnectAttempts += 1
        let delay = Double(reconnectAttempts) * 2.0

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(delay))
            self.connect()
        }
    }

    private func startPingTimer() {
        stopPingTimer()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.sendPing() }
        }
    }

    private func stopPingTimer() {
        pingTimer?.invalidate()
        pingTimer = nil
    }
}
