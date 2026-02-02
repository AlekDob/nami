import Foundation
#if canImport(UIKit)
import UIKit
import UniformTypeIdentifiers

enum SharedContent: Sendable {
    case url(URL, title: String?)
    case text(String)
    case image(Data, filename: String)
    case pdf(Data, filename: String)
}

enum ContentExtractor {
    static func extract(
        from items: [NSExtensionItem]
    ) async -> [SharedContent] {
        var results: [SharedContent] = []

        for item in items {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                if let content = await extractSingle(
                    from: provider, title: item.attributedContentText?.string
                ) {
                    results.append(content)
                }
            }
        }
        return results
    }

    private static func extractSingle(
        from provider: NSItemProvider,
        title: String?
    ) async -> SharedContent? {
        // URL
        if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
            return await extractURL(from: provider, title: title)
        }
        // Image
        if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier) {
            return await extractImage(from: provider)
        }
        // PDF
        if provider.hasItemConformingToTypeIdentifier(UTType.pdf.identifier) {
            return await extractPDF(from: provider)
        }
        // Plain text (check last to avoid matching URLs as text)
        if provider.hasItemConformingToTypeIdentifier(
            UTType.plainText.identifier
        ) {
            return await extractText(from: provider)
        }
        return nil
    }

    private static func extractURL(
        from provider: NSItemProvider, title: String?
    ) async -> SharedContent? {
        do {
            let item = try await provider.loadItem(
                forTypeIdentifier: UTType.url.identifier
            )
            if let url = item as? URL {
                return .url(url, title: title)
            }
            if let data = item as? Data, let url = URL(
                string: String(data: data, encoding: .utf8) ?? ""
            ) {
                return .url(url, title: title)
            }
        } catch {}
        return nil
    }

    private static func extractText(
        from provider: NSItemProvider
    ) async -> SharedContent? {
        do {
            let item = try await provider.loadItem(
                forTypeIdentifier: UTType.plainText.identifier
            )
            if let text = item as? String, !text.isEmpty {
                return .text(text)
            }
        } catch {}
        return nil
    }

    private static func extractImage(
        from provider: NSItemProvider
    ) async -> SharedContent? {
        do {
            let item = try await provider.loadItem(
                forTypeIdentifier: UTType.image.identifier
            )
            var imageData: Data?

            if let url = item as? URL {
                imageData = try? Data(contentsOf: url)
            } else if let data = item as? Data {
                imageData = data
            } else if let image = item as? UIImage {
                imageData = image.jpegData(compressionQuality: 0.6)
            }

            guard let data = imageData else { return nil }

            // Compress if it's a large image
            let compressed = compressImage(data: data)
            let name = "shared_\(UUID().uuidString.prefix(8)).jpg"
            return .image(compressed, filename: name)
        } catch {}
        return nil
    }

    private static func extractPDF(
        from provider: NSItemProvider
    ) async -> SharedContent? {
        do {
            let item = try await provider.loadItem(
                forTypeIdentifier: UTType.pdf.identifier
            )
            if let url = item as? URL {
                let data = try Data(contentsOf: url)
                return .pdf(data, filename: url.lastPathComponent)
            }
            if let data = item as? Data {
                return .pdf(data, filename: "shared.pdf")
            }
        } catch {}
        return nil
    }

    private static func compressImage(data: Data) -> Data {
        guard let image = UIImage(data: data) else { return data }
        // Limit to 1024px max dimension for share extension memory
        let maxDimension: CGFloat = 1024
        let size = image.size
        if size.width <= maxDimension && size.height <= maxDimension {
            return image.jpegData(compressionQuality: 0.6) ?? data
        }
        let scale = maxDimension / max(size.width, size.height)
        let newSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        return resized.jpegData(compressionQuality: 0.6) ?? data
    }
}
#endif
