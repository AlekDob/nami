import Foundation

// MARK: - Content Parts (Multimodal)

enum ContentPart: Codable, Equatable {
    case text(String)
    case image(String) // base64 data URI

    enum CodingKeys: String, CodingKey {
        case type, text, image
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "text":
            self = .text(try container.decode(String.self, forKey: .text))
        case "image":
            self = .image(try container.decode(String.self, forKey: .image))
        default:
            self = .text("[unsupported: \(type)]")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .image(let data):
            try container.encode("image", forKey: .type)
            try container.encode(data, forKey: .image)
        }
    }
}

enum MessageContent: Equatable {
    case text(String)
    case parts([ContentPart])

    var textContent: String {
        switch self {
        case .text(let s): return s
        case .parts(let parts):
            return parts.compactMap {
                if case .text(let t) = $0 { return t }
                return nil
            }.joined(separator: " ")
        }
    }

    var images: [String] {
        switch self {
        case .text: return []
        case .parts(let parts):
            return parts.compactMap {
                if case .image(let data) = $0 { return data }
                return nil
            }
        }
    }

    var hasImages: Bool { !images.isEmpty }
}

extension MessageContent: Codable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .text(str)
        } else {
            let parts = try container.decode([ContentPart].self)
            self = .parts(parts)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let s):
            try container.encode(s)
        case .parts(let parts):
            try container.encode(parts)
        }
    }
}

// MARK: - Chat

struct ChatMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let role: MessageRole
    let content: MessageContent
    let timestamp: Date

    init(role: MessageRole, content: String) {
        self.id = UUID()
        self.role = role
        self.content = .text(content)
        self.timestamp = Date()
    }

    init(role: MessageRole, text: String, images: [String]) {
        self.id = UUID()
        self.role = role
        self.timestamp = Date()
        if images.isEmpty {
            self.content = .text(text)
        } else {
            var parts: [ContentPart] = []
            if !text.isEmpty { parts.append(.text(text)) }
            parts.append(contentsOf: images.map { .image($0) })
            self.content = .parts(parts)
        }
    }

    enum CodingKeys: String, CodingKey {
        case role, content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = UUID()
        self.role = try container.decode(MessageRole.self, forKey: .role)
        self.content = try container.decode(MessageContent.self, forKey: .content)
        self.timestamp = Date()
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

struct ChatRequest: Codable {
    let messages: [ChatMessage]
}

struct ChatResponse: Codable {
    let text: String
    let stats: ChatStats?
    let toolsUsed: [String]?
}

struct ChatStats: Codable, Equatable {
    let model: String?
    let inputTokens: Int?
    let outputTokens: Int?
    let durationMs: Int?
}

// MARK: - Status

struct ServerStatus: Codable {
    let uptime: Double?
    let model: String?
    let memory: ServerMemory?
    let channels: [String: Bool]?
}

struct ServerMemory: Codable {
    let rss: Int?
    let heap: Int?
}

// MARK: - Models

struct ModelsResponse: Codable {
    let models: String
}

struct ModelInfo: Codable, Identifiable, Equatable {
    let id: String
    let label: String
    let preset: String
    let vision: Bool
    let toolUse: Bool
    let current: Bool
}

struct ModelListResponse: Codable {
    let models: [ModelInfo]
}

struct SetModelRequest: Codable {
    let id: String
}

struct SetModelResponse: Codable {
    let message: String
}

// MARK: - Memory Search

struct MemorySearchResponse: Codable {
    let query: String
    let results: [MemoryResult]
}

struct MemoryResult: Codable, Identifiable {
    var id: String { "\(path):\(startLine)" }
    let path: String
    let startLine: Int
    let endLine: Int
    let score: Double
    let snippet: String
    let source: String?
}

struct MemoryLinesResponse: Codable {
    let path: String
    let from: Int
    let count: Int
    let text: String
}

struct MemoryRecentResponse: Codable {
    let results: [MemoryResult]
}

// MARK: - Jobs

struct Job: Codable, Identifiable {
    let id: String
    let name: String
    let cron: String
    let task: String
    let userId: String?
    let enabled: Bool
    let notify: Bool?
    let `repeat`: Bool?
    let lastRun: String?
}

struct CreateJobRequest: Codable {
    let name: String
    let cron: String
    let task: String
    let `repeat`: Bool?
    let notify: Bool?
}

struct DeleteJobResponse: Codable {
    let success: Bool
}

// MARK: - Soul

struct SoulResponse: Codable {
    let content: String
}

struct SoulUpdateRequest: Codable {
    let content: String
}

// MARK: - Device Registration

struct RegisterDeviceRequest: Codable {
    let token: String
}

struct RegisterDeviceResponse: Codable {
    let success: Bool
}

// MARK: - Health

struct HealthResponse: Codable {
    let ok: Bool
}

// MARK: - WebSocket

enum WSOutgoing: Codable {
    case chat(messages: [ChatMessage])
    case ping

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .chat(let messages):
            try container.encode("chat", forKey: .type)
            try container.encode(messages, forKey: .messages)
        case .ping:
            try container.encode("ping", forKey: .type)
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "chat":
            let msgs = try container.decode([ChatMessage].self, forKey: .messages)
            self = .chat(messages: msgs)
        default:
            self = .ping
        }
    }

    enum CodingKeys: String, CodingKey {
        case type, messages
    }
}

enum WSIncoming: Codable {
    case done(text: String, stats: ChatStats?)
    case toolUse(tool: String)
    case notification(title: String, body: String)
    case pong
    case error(error: String)

    enum CodingKeys: String, CodingKey {
        case type, text, stats, title, body, error, tool
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "done":
            let text = try container.decode(String.self, forKey: .text)
            let stats = try container.decodeIfPresent(ChatStats.self, forKey: .stats)
            self = .done(text: text, stats: stats)
        case "tool_use":
            let tool = try container.decode(String.self, forKey: .tool)
            self = .toolUse(tool: tool)
        case "notification":
            let title = try container.decode(String.self, forKey: .title)
            let body = try container.decode(String.self, forKey: .body)
            self = .notification(title: title, body: body)
        case "pong":
            self = .pong
        case "error":
            let error = try container.decode(String.self, forKey: .error)
            self = .error(error: error)
        default:
            self = .error(error: "Unknown message type: \(type)")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .done(let text, let stats):
            try container.encode("done", forKey: .type)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(stats, forKey: .stats)
        case .toolUse(let tool):
            try container.encode("tool_use", forKey: .type)
            try container.encode(tool, forKey: .tool)
        case .notification(let title, let body):
            try container.encode("notification", forKey: .type)
            try container.encode(title, forKey: .title)
            try container.encode(body, forKey: .body)
        case .pong:
            try container.encode("pong", forKey: .type)
        case .error(let error):
            try container.encode("error", forKey: .type)
            try container.encode(error, forKey: .error)
        }
    }
}
