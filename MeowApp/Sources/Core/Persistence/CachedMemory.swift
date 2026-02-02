import Foundation
import SwiftData

@Model
final class CachedMemoryEntry {
    var query: String
    var path: String
    var startLine: Int
    var endLine: Int
    var score: Double
    var snippet: String
    var source: String
    var cachedAt: Date

    init(
        query: String,
        path: String,
        startLine: Int,
        endLine: Int,
        score: Double,
        snippet: String,
        source: String
    ) {
        self.query = query
        self.path = path
        self.startLine = startLine
        self.endLine = endLine
        self.score = score
        self.snippet = snippet
        self.source = source
        self.cachedAt = Date()
    }
}

extension CachedMemoryEntry {
    static func fromAPIResult(query: String, result: MemoryResult) -> CachedMemoryEntry {
        CachedMemoryEntry(
            query: query,
            path: result.path,
            startLine: result.startLine,
            endLine: result.endLine,
            score: result.score,
            snippet: result.snippet,
            source: result.source ?? "unknown"
        )
    }

    func toMemoryResult() -> MemoryResult {
        MemoryResult(
            path: path,
            startLine: startLine,
            endLine: endLine,
            score: score,
            snippet: snippet,
            source: source
        )
    }
}

@Model
final class CachedFileContent {
    @Attribute(.unique) var path: String
    var content: String
    var cachedAt: Date

    init(path: String, content: String) {
        self.path = path
        self.content = content
        self.cachedAt = Date()
    }
}

// MARK: - Chat Persistence

@Model
final class CachedChatMessage {
    @Attribute(.unique) var messageId: String
    var role: String
    var content: String
    var timestamp: Date

    init(role: String, content: String, messageId: String = UUID().uuidString) {
        self.messageId = messageId
        self.role = role
        self.content = content
        self.timestamp = Date()
    }
}

extension CachedChatMessage {
    static func from(_ message: ChatMessage) -> CachedChatMessage {
        CachedChatMessage(
            role: message.role.rawValue,
            content: message.content,
            messageId: message.id.uuidString
        )
    }

    func toChatMessage() -> ChatMessage {
        ChatMessage(role: MessageRole(rawValue: role) ?? .system, content: content)
    }
}
