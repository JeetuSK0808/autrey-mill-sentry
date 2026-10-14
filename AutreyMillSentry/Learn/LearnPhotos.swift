import Foundation
import CoreGraphics
import ImageIO

/// Reference photos picked by `tools/pick_learn_photos.py` (one licensed iNaturalist photo per species) with attribution.
struct LearnPhoto: Codable, Sendable {
    var file: String
    var observer: String
    var license: String
    var photoURL: String
    var observationURL: String
    var modelProbability: Double?
    var tier: String?

    var licenseName: String {
        switch license {
        case "cc0": return "CC0"
        case "cc-by": return "CC BY 4.0"
        case "cc-by-nc": return "CC BY-NC 4.0"
        default: return license.uppercased()
        }
    }
    var credit: String { "Photo: \(observer), \(licenseName), via iNaturalist" }
}

final class LearnPhotos {
    static let shared = LearnPhotos()
    private(set) var photos: [String: LearnPhoto] = [:]
    private var cache: [String: CGImage] = [:]
    private let lock = NSLock()

    init(bundle: Bundle = .main) {
        if let url = bundle.url(forResource: "learn_photos", withExtension: "json"), let data = try? Data(contentsOf: url),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let dict = obj["photos"] as? [String: Any],
           let raw = try? JSONSerialization.data(withJSONObject: dict), let parsed = try? JSONDecoder().decode([String: LearnPhoto].self, from: raw) {
            photos = parsed
        }
    }

    func photo(for label: String) -> LearnPhoto? { photos[label] }

    func image(for label: String, maxPixel: Int = 1200, bundle: Bundle = .main) -> CGImage? {
        let key = "\(label)@\(maxPixel)"
        lock.lock(); if let c = cache[key] { lock.unlock(); return c }; lock.unlock()
        guard let p = photos[label], let url = bundle.url(forResource: p.file.replacingOccurrences(of: ".jpg", with: ""), withExtension: "jpg"),
              let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceThumbnailMaxPixelSize: maxPixel, kCGImageSourceCreateThumbnailWithTransform: true]
        guard let img = CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary) else { return nil }
        lock.lock(); cache[key] = img; lock.unlock()
        return img
    }
}
