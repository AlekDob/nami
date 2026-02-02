import Foundation

struct PendingShare: Codable, Sendable {
    let id: UUID
    let message: String
    let createdAt: Date
}

enum PendingShareQueue {
    private static var fileURL: URL {
        let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: SharedConfig.appGroupID
        )
        let dir = container ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("pending_shares.json")
    }

    static func enqueue(message: String) {
        var items = loadAll()
        let item = PendingShare(
            id: UUID(),
            message: message,
            createdAt: Date()
        )
        items.append(item)
        save(items)
    }

    static func dequeueAll() -> [PendingShare] {
        let items = loadAll()
        if !items.isEmpty {
            try? FileManager.default.removeItem(at: fileURL)
        }
        return items
    }

    static func remove(id: UUID) {
        var items = loadAll()
        items.removeAll { $0.id == id }
        save(items)
    }

    // MARK: - Private

    private static func loadAll() -> [PendingShare] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return []
        }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([PendingShare].self, from: data)
        } catch {
            return []
        }
    }

    private static func save(_ items: [PendingShare]) {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[PendingShareQueue] save error: \(error)")
        }
    }
}
