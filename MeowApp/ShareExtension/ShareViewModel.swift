#if canImport(UIKit)
import Foundation
import UIKit

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

    /// Opens the main app with shared content pre-filled in chat input
    func openInApp(extensionContext: NSExtensionContext?) {
        guard !extractedContent.isEmpty else {
            print("[ShareExt] No content to share")
            return
        }

        isSending = true

        // Save content to shared storage for the main app to read
        let payload = buildPayload()
        SharedConfig.sharedDefaults.set(payload, forKey: "com.meow.pendingShare")
        SharedConfig.sharedDefaults.synchronize()

        print("[ShareExt] saved pending share: \(payload.prefix(100))...")
        print("[ShareExt] sharedDefaults verify: \(SharedConfig.sharedDefaults.string(forKey: "com.meow.pendingShare")?.prefix(50) ?? "nil")")

        // Open main app via URL scheme
        guard let url = URL(string: "meow://share") else {
            print("[ShareExt] Failed to create URL")
            isSending = false
            return
        }

        print("[ShareExt] Attempting to open URL: \(url)")

        // Use responder chain to open URL (works better than extensionContext.open)
        openURLViaResponderChain(url)

        isDone = true
        isSending = false
    }

    /// Opens URL via selector on shared UIApplication
    /// This workaround uses the undocumented ability to access UIApplication
    /// from an extension via the shared selector
    @discardableResult
    private func openURLViaResponderChain(_ url: URL) -> Bool {
        // Access UIApplication via class method selector
        let selectorOpenURL = sel_registerName("openURL:")

        guard let applicationClass = NSClassFromString("UIApplication") else {
            print("[ShareExt] UIApplication class not found")
            return false
        }

        // Get shared application instance
        let sharedAppSelector = NSSelectorFromString("sharedApplication")
        guard applicationClass.responds(to: sharedAppSelector) else {
            print("[ShareExt] sharedApplication selector not found")
            return false
        }

        let sharedApp = (applicationClass as AnyObject).perform(sharedAppSelector)?.takeUnretainedValue()

        // Call openURL: on the shared application
        guard let app = sharedApp, (app as AnyObject).responds(to: selectorOpenURL) else {
            print("[ShareExt] openURL: selector not found")
            return false
        }

        print("[ShareExt] Calling openURL via selector")
        _ = (app as AnyObject).perform(selectorOpenURL, with: url)
        return true
    }

    /// Legacy: send directly to server (kept for offline queue)
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
            PendingShareQueue.enqueue(message: message)
            isDone = true
        }

        isSending = false
    }

    // MARK: - Payload

    private func buildPayload() -> String {
        var parts: [String] = []

        for content in extractedContent {
            switch content {
            case .url(let url, _):
                parts.append(url.absoluteString)
            case .text(let text):
                parts.append(text)
            case .image(let data, _):
                // Store as base64 data URI
                let base64 = data.base64EncodedString()
                parts.append("data:image/jpeg;base64,\(base64)")
            case .pdf(_, let name):
                parts.append("[PDF: \(name)]")
            }
        }

        if !note.isEmpty {
            parts.append("\n\(note)")
        }

        return parts.joined(separator: "\n")
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
