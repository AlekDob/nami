import Foundation
import SwiftUI
import SwiftData

@MainActor
@Observable
final class ChatViewModel {
    var messages: [ChatMessage] = []
    var inputText = ""
    var isThinking = false
    var activeTools: [String] = []
    var lastStats: ChatStats?
    var lastToolsUsed: [String]?
    var errorMessage: String?

    let speechRecognizer = SpeechRecognizer()

    private let apiClient: MeowAPIClient
    private let wsManager: WebSocketManager
    private var modelContext: ModelContext?

    init(apiClient: MeowAPIClient, wsManager: WebSocketManager) {
        self.apiClient = apiClient
        self.wsManager = wsManager
        setupWebSocketHandler()
        speechRecognizer.requestPermissions()
    }

    func toggleVoiceInput() {
        if speechRecognizer.isRecording {
            speechRecognizer.stopRecording()
            let text = speechRecognizer.transcript
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                inputText = text
            }
        } else {
            speechRecognizer.startRecording()
        }
    }

    func setModelContext(_ context: ModelContext) {
        modelContext = context
        loadPersistedMessages()
    }

    var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isThinking
    }

    var catMood: CatMood {
        if isThinking { return .thinking }
        if errorMessage != nil { return .error }
        if messages.isEmpty { return .idle }
        return .happy
    }

    func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: trimmed)
        messages.append(userMessage)
        persistMessage(userMessage)
        inputText = ""
        isThinking = true
        activeTools = []
        errorMessage = nil

        // Prefer WebSocket for real-time tool_use events
        if wsManager.isConnected {
            wsManager.sendChat(messages: messages)
        } else {
            // Try connecting WS in background for tool events while using REST
            wsManager.connect()
            sendViaREST()
        }
    }

    func clearChat() {
        messages.removeAll()
        lastStats = nil
        lastToolsUsed = nil
        errorMessage = nil
        clearPersistedMessages()
    }

    // MARK: - Persistence

    private func loadPersistedMessages() {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<CachedChatMessage>(
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        do {
            let cached = try context.fetch(descriptor)
            if !cached.isEmpty {
                messages = cached.map { $0.toChatMessage() }
            }
        } catch {
            print("[Chat] Failed to load messages: \(error)")
        }
    }

    private func persistMessage(_ message: ChatMessage) {
        guard let context = modelContext else { return }
        let cached = CachedChatMessage.from(message)
        context.insert(cached)
        try? context.save()
    }

    private func clearPersistedMessages() {
        guard let context = modelContext else { return }
        do {
            try context.delete(model: CachedChatMessage.self)
            try context.save()
        } catch {
            print("[Chat] Failed to clear messages: \(error)")
        }
    }

    // MARK: - Network

    private func sendViaREST() {
        Task { @MainActor in
            do {
                let response = try await apiClient.sendChat(messages: messages)
                handleResponse(text: response.text, stats: response.stats, toolsUsed: response.toolsUsed)
            } catch {
                handleError(error)
            }
        }
    }

    private func handleResponse(text: String, stats: ChatStats?, toolsUsed: [String]? = nil) {
        let reply = ChatMessage(role: .assistant, content: text)
        messages.append(reply)
        persistMessage(reply)
        lastStats = stats
        lastToolsUsed = toolsUsed ?? (activeTools.isEmpty ? nil : activeTools)
        activeTools = []
        isThinking = false
    }

    private func handleError(_ error: Error) {
        isThinking = false
        activeTools = []
        errorMessage = error.localizedDescription
    }

    private func setupWebSocketHandler() {
        wsManager.onMessage = { [weak self] incoming in
            guard let self else { return }
            switch incoming {
            case .done(let text, let stats):
                self.handleResponse(text: text, stats: stats)
            case .toolUse(let tool):
                self.handleToolUse(tool)
            case .notification(let title, let body):
                self.handleNotification(title: title, body: body)
            case .error(let error):
                self.handleError(APIError.httpError(status: 0, body: error))
            case .pong:
                break
            }
        }
    }

    private func handleToolUse(_ tool: String) {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            if !activeTools.contains(tool) {
                activeTools.append(tool)
            }
        }
    }

    private func handleNotification(title: String, body: String) {
        let notification = ChatMessage(
            role: .system,
            content: "[\(title)] \(body)"
        )
        messages.append(notification)
        persistMessage(notification)
    }
}
