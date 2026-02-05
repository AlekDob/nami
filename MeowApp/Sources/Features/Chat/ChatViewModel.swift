import Foundation
import SwiftUI
import SwiftData
import PhotosUI
import Combine
#if os(iOS)
import UIKit
#endif

extension Notification.Name {
    static let pendingShareReceived = Notification.Name("pendingShareReceived")
}

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

    // Image attachment state
    var pendingImages: [PlatformImage] = []
    var selectedPhotoItems: [PhotosPickerItem] = []

    // Typewriter effect state
    var typewriterMessageID: UUID?
    var typewriterDisplayedText: String = ""
    private var typewriterTask: Task<Void, Never>?

    let speechRecognizer = SpeechRecognizer()
    let tts = TextToSpeechService()

    private let apiClient: MeowAPIClient
    private let wsManager: WebSocketManager
    private var modelContext: ModelContext?
    private var shareObserver: AnyCancellable?

    init(apiClient: MeowAPIClient, wsManager: WebSocketManager) {
        self.apiClient = apiClient
        self.wsManager = wsManager
        setupWebSocketHandler()
        speechRecognizer.requestPermissions()
        setupShareObserver()
        checkPendingShare()
    }

    private func setupShareObserver() {
        shareObserver = NotificationCenter.default
            .publisher(for: .pendingShareReceived)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                if let content = notification.object as? String {
                    self?.handleSharedContent(content)
                }
            }
    }

    private func checkPendingShare() {
        // Check on launch if there's pending shared content
        if let content = SharedConfig.sharedDefaults.string(
            forKey: "com.meow.pendingShare"
        ), !content.isEmpty {
            SharedConfig.sharedDefaults.removeObject(forKey: "com.meow.pendingShare")
            handleSharedContent(content)
        }
    }

    func handleSharedContent(_ content: String) {
        print("[Chat] handling shared content: \(content.prefix(100))...")

        // Check if it's an image (base64 data URI)
        if content.hasPrefix("data:image/") {
            // Extract base64 and convert to image
            if let commaIndex = content.firstIndex(of: ",") {
                let base64 = String(content[content.index(after: commaIndex)...])
                if let data = Data(base64Encoded: base64) {
                    #if canImport(UIKit)
                    if let image = UIImage(data: data) {
                        pendingImages.append(image)
                        print("[Chat] added shared image to pending")
                    }
                    #endif
                }
            }
        } else {
            // Text or URL - put in input field
            inputText = content
            print("[Chat] set inputText from share")
        }
    }

    // MARK: - Image Management

    func addImage(_ image: PlatformImage) {
        guard pendingImages.count < ImageCompressor.maxImages else { return }
        pendingImages.append(image)
    }

    func removeImage(at index: Int) {
        guard pendingImages.indices.contains(index) else { return }
        pendingImages.remove(at: index)
    }

    func handlePhotoSelection() async {
        for item in selectedPhotoItems {
            guard pendingImages.count < ImageCompressor.maxImages else { break }
            if let data = try? await item.loadTransferable(type: Data.self) {
                #if canImport(UIKit)
                if let image = UIImage(data: data) { pendingImages.append(image) }
                #else
                if let image = NSImage(data: data) { pendingImages.append(image) }
                #endif
            }
        }
        selectedPhotoItems = []
    }

    // MARK: - Voice

    func toggleVoiceInput() {
        if speechRecognizer.isRecording {
            triggerHaptic(.medium)
            speechRecognizer.stopRecording()
            let text = speechRecognizer.transcript
            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                inputText = text
                autoSendAfterVoice()
            }
        } else {
            guard speechRecognizer.isAvailable else {
                errorMessage = speechRecognizer.permissionErrorMessage
                triggerHaptic(.error)
                return
            }
            triggerHaptic(.heavy)
            speechRecognizer.startRecording()
        }
    }

    private func triggerHaptic(_ style: HapticStyle) {
        #if os(iOS)
        switch style {
        case .heavy:
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        case .medium:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .error:
            UINotificationFeedbackGenerator().notificationOccurred(.error)
        }
        #endif
    }

    private enum HapticStyle { case heavy, medium, error }

    private func autoSendAfterVoice() {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(600))
            guard canSend else { return }
            sendMessage()
        }
    }

    // MARK: - Persistence Setup

    func setModelContext(_ context: ModelContext) {
        modelContext = context
        loadPersistedMessages()
    }

    var canSend: Bool {
        let hasText = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return (hasText || !pendingImages.isEmpty) && !isThinking
    }

    var catMood: CatMood {
        if isThinking { return .thinking }
        if errorMessage != nil { return .error }
        if messages.isEmpty { return .idle }
        return .happy
    }

    // MARK: - Send

    func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !pendingImages.isEmpty else { return }

        let userMessage: ChatMessage
        if pendingImages.isEmpty {
            userMessage = ChatMessage(role: .user, content: trimmed)
        } else {
            let base64Images = pendingImages.compactMap { ImageCompressor.compress($0) }
            let text = trimmed.isEmpty ? "describe this image" : trimmed
            userMessage = ChatMessage(role: .user, text: text, images: base64Images)
        }

        messages.append(userMessage)
        persistMessage(userMessage)
        inputText = ""
        pendingImages = []
        selectedPhotoItems = []
        isThinking = true
        activeTools = []
        errorMessage = nil

        if wsManager.isConnected {
            wsManager.sendChat(messages: messages)
        } else {
            wsManager.connect()
            sendViaREST()
        }
    }

    func clearChat() {
        messages.removeAll()
        lastStats = nil
        lastToolsUsed = nil
        errorMessage = nil
        pendingImages = []
        selectedPhotoItems = []
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

        // Start typewriter effect
        startTypewriter(text: text, messageID: reply.id)

        if tts.autoSpeak {
            tts.speak(text, messageID: reply.id)
        }
    }

    // MARK: - Typewriter Effect

    private func startTypewriter(text: String, messageID: UUID) {
        // Cancel any existing typewriter
        typewriterTask?.cancel()
        typewriterTask = nil

        typewriterMessageID = messageID
        typewriterDisplayedText = ""

        typewriterTask = Task {
            let chars = Array(text)
            var displayed = ""

            for char in chars {
                if Task.isCancelled { break }

                displayed.append(char)
                typewriterDisplayedText = displayed

                // ~50 chars/sec for natural feel
                try? await Task.sleep(nanoseconds: 20_000_000)
            }

            // Typewriter complete
            typewriterMessageID = nil
        }
    }

    func skipTypewriter() {
        typewriterTask?.cancel()
        typewriterTask = nil
        typewriterMessageID = nil
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
            case .creation(let id, let name, let type):
                self.handleCreation(id: id, name: name, type: type)
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

    private func handleCreation(id: String, name: String, type: String) {
        let info = CreationInfo(id: id, name: name, type: type)
        let creationMsg = ChatMessage(creation: info)
        messages.append(creationMsg)
        // Don't persist creation messages - they're transient UI
    }
}
