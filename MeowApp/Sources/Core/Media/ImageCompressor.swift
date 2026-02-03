import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
typealias PlatformImage = NSImage
#endif

enum ImageCompressor {
    static let maxDimension: CGFloat = 1024
    static let targetBytes = 500_000
    static let maxImages = 3

    static func compress(_ image: PlatformImage) -> String? {
        guard let resized = resize(image, maxSide: maxDimension) else { return nil }
        // Try progressively lower quality until under target size
        for quality in [0.7, 0.5, 0.3] {
            guard let data = jpegData(from: resized, quality: quality) else { continue }
            if data.count <= targetBytes {
                return "data:image/jpeg;base64," + data.base64EncodedString()
            }
        }
        // Last resort: lowest quality
        guard let data = jpegData(from: resized, quality: 0.1) else { return nil }
        return "data:image/jpeg;base64," + data.base64EncodedString()
    }

    static func decodeBase64Image(_ dataURI: String) -> PlatformImage? {
        let base64 = dataURI
            .replacingOccurrences(of: "data:image/jpeg;base64,", with: "")
            .replacingOccurrences(of: "data:image/png;base64,", with: "")
        guard let data = Data(base64Encoded: base64) else { return nil }
        #if canImport(UIKit)
        return UIImage(data: data)
        #else
        return NSImage(data: data)
        #endif
    }

    // MARK: - Private

    private static func resize(_ image: PlatformImage, maxSide: CGFloat) -> PlatformImage? {
        #if canImport(UIKit)
        let size = image.size
        let scale = min(maxSide / max(size.width, size.height), 1.0)
        if scale >= 1.0 { return image }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in image.draw(in: CGRect(origin: .zero, size: newSize)) }
        #else
        let size = image.size
        let scale = min(maxSide / max(size.width, size.height), 1.0)
        if scale >= 1.0 { return image }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        image.draw(in: CGRect(origin: .zero, size: newSize))
        newImage.unlockFocus()
        return newImage
        #endif
    }

    private static func jpegData(from image: PlatformImage, quality: Double) -> Data? {
        #if canImport(UIKit)
        return image.jpegData(compressionQuality: quality)
        #else
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
        #endif
    }
}
