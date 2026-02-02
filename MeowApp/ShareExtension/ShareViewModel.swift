#if canImport(UIKit)
import Foundation

@MainActor
@Observable
final class ShareViewModel {
    var note = ""
    var extractedContent: [SharedContent] = []
    var isSending = false
    var isDone = false
    var errorMessage: String?

    func extractContent(from items: [NSExtensionItem]) async {
        extractedContent = await ContentExtractor.extract(from: items)
    }

    func send() async {
        guard !extractedContent.isEmpty else { return }

        isSending = true
        errorMessage = nil

        let message = formatMessage()

        guard SharedConfig.isConfigured else {
            errorMessage = "Open MeowApp to configure server"
            isSending = false
            return
        }

        let client = ShareAPIClient(
            baseURL: SharedConfig.serverURL,
            apiKey: SharedConfig.apiKey
        )

        do {
            try await client.sendToMeow(message: message)
            isDone = true
        } catch {
            // Queue for later retry
            PendingShareQueue.enqueue(message: message)
            isDone = true
        }

        isSending = false
    }

    var contentPreviewText: String {
        guard let first = extractedContent.first else {
            return "No content"
        }
        switch first {
        case .url(let url, let title):
            return title ?? url.absoluteString
        case .text(let text):
            let trimmed = text.prefix(120)
            return String(trimmed) + (text.count > 120 ? "..." : "")
        case .image(_, let name):
            return "Image: \(name)"
        case .pdf(_, let name):
            return "PDF: \(name)"
        }
    }

    var contentIcon: String {
        guard let first = extractedContent.first else {
            return "doc"
        }
        switch first {
        case .url: return "link"
        case .text: return "doc.text"
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        }
    }

    // MARK: - Private

    private func formatMessage() -> String {
        var parts: [String] = []

        for content in extractedContent {
            switch content {
            case .url(let url, let title):
                parts.append("[SHARED] Bookmark from share sheet")
                parts.append("URL: \(url.absoluteString)")
                if let title, !title.isEmpty {
                    parts.append("Title: \(title)")
                }
            case .text(let text):
                parts.append("[SHARED] Text snippet from share sheet")
                parts.append("Content: \"\(text)\"")
            case .image(_, let filename):
                parts.append("[SHARED] Image from share sheet")
                parts.append("Filename: \(filename)")
            case .pdf(_, let filename):
                parts.append("[SHARED] PDF from share sheet")
                parts.append("Filename: \(filename)")
            }
        }

        if !note.isEmpty {
            parts.append("Note: \(note)")
        }

        parts.append("")
        parts.append("Please save this to memory as a bookmark.")

        return parts.joined(separator: "\n")
    }
}
#endif
