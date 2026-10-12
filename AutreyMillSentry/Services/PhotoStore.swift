import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

/// Stores report photos as plain JPEG files in Application Support. Re-encoding from a CGImage drops every
/// EXIF/GPS/device tag; nothing is written to the Photos library.
enum PhotoStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Photos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func url(for fileName: String) -> URL { directory.appendingPathComponent(fileName) }

    /// Writes `image` as JPEG with no metadata and returns the file name.
    @discardableResult
    static func save(_ image: CGImage, id: UUID, maxDimension: Int = 1600, quality: CGFloat = 0.85) throws -> String {
        let fileName = "\(id.uuidString).jpg"
        let resized = resize(image, maxDimension: maxDimension) ?? image
        let url = url(for: fileName)
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        // Only the compression option: no EXIF, no GPS, no maker notes.
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(dest, resized, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { throw CocoaError(.fileWriteUnknown) }
        return fileName
    }

    static func load(_ fileName: String) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url(for: fileName) as CFURL, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(src, 0, nil)
    }

    static func thumbnail(_ fileName: String, maxPixel: Int = 300) -> CGImage? {
        guard let src = CGImageSourceCreateWithURL(url(for: fileName) as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: maxPixel, kCGImageSourceCreateThumbnailWithTransform: true]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
    }

    static func delete(_ fileName: String) { try? FileManager.default.removeItem(at: url(for: fileName)) }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    static func resize(_ image: CGImage, maxDimension: Int) -> CGImage? {
        let w = image.width, h = image.height
        let scale = min(1, Double(maxDimension) / Double(max(w, h)))
        if scale >= 1 { return image }
        let nw = Int(Double(w) * scale), nh = Int(Double(h) * scale)
        guard let ctx = CGContext(data: nil, width: nw, height: nh, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: nw, height: nh))
        return ctx.makeImage()
    }
}
