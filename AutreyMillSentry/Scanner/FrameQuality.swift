import Foundation
import CoreGraphics
import CoreVideo
import Vision
import ImageIO

/// Computes QualityMetrics for a frame: sharpness (variance of Laplacian), exposure, subject size (Vision saliency),
/// person presence (Vision human/face detection) and motion (difference from the previous frame).
final class QualityAnalyzer {
    private let side = 256
    private var previousGray: [UInt8]?
    private lazy var grayContext: CGContext? = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8, bytesPerRow: side,
                                                          space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)

    func reset() { previousGray = nil }

    func analyze(_ image: CGImage, orientation: CGImagePropertyOrientation, trackMotion: Bool, detectPeople: Bool = true) -> QualityMetrics {
        var m = QualityMetrics()
        if let gray = grayPixels(of: image) {
            let stats = Self.stats(gray: gray, side: side)
            m.sharpness = stats.laplacianVariance
            m.meanLuminance = stats.meanLuminance
            m.clippedFraction = stats.clippedFraction
            if trackMotion, let prev = previousGray {
                m.motion = Self.meanAbsDiff(gray, prev)
            }
            previousGray = trackMotion ? gray : nil
        }
        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
        var requests: [VNRequest] = []
        let saliency = VNGenerateAttentionBasedSaliencyImageRequest()
        requests.append(saliency)
        let humans = VNDetectHumanRectanglesRequest()
        humans.upperBodyOnly = true
        let faces = VNDetectFaceRectanglesRequest()
        if detectPeople { requests.append(humans); requests.append(faces) }
        try? handler.perform(requests)
        if let obs = saliency.results?.first, let boxes = obs.salientObjects, !boxes.isEmpty {
            let union = boxes.map(\.boundingBox).reduce(boxes[0].boundingBox) { $0.union($1) }
            m.subjectFraction = Double(union.width * union.height)
            m.subjectBox = QualityMetrics.SubjectBox(x: Double(union.minX), y: Double(union.minY), width: Double(union.width), height: Double(union.height))
            let edges = [union.minX <= 0.02, union.minY <= 0.02, union.maxX >= 0.98, union.maxY >= 0.98].filter { $0 }.count
            m.subjectTouchesEdges = edges >= 3
        } else {
            // No salient region: treat the whole frame as the subject so the gate falls through to the classifier.
            m.subjectFraction = 0.5
        }
        if detectPeople {
            let humanArea = (humans.results ?? []).map { Double($0.boundingBox.width * $0.boundingBox.height) }.max() ?? 0
            let faceArea = (faces.results ?? []).map { Double($0.boundingBox.width * $0.boundingBox.height) }.max() ?? 0
            m.personDetected = humanArea > 0.10 || faceArea > 0.008
        }
        return m
    }

    func analyze(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, trackMotion: Bool) -> QualityMetrics {
        guard let cg = Self.cgImage(from: pixelBuffer) else { return QualityMetrics() }
        return analyze(cg, orientation: orientation, trackMotion: trackMotion)
    }

    // MARK: helpers

    private func grayPixels(of image: CGImage) -> [UInt8]? {
        guard let ctx = grayContext else { return nil }
        ctx.interpolationQuality = .low
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        guard let data = ctx.data else { return nil }
        let buf = data.bindMemory(to: UInt8.self, capacity: side * side)
        return Array(UnsafeBufferPointer(start: buf, count: side * side))
    }

    struct GrayStats { var laplacianVariance: Double; var meanLuminance: Double; var clippedFraction: Double }

    static func stats(gray: [UInt8], side: Int) -> GrayStats {
        var sum = 0.0, clipped = 0
        for v in gray { sum += Double(v); if v >= 250 { clipped += 1 } }
        let n = Double(gray.count)
        var lapSum = 0.0, lapSq = 0.0, count = 0.0
        for y in 1..<(side - 1) {
            for x in 1..<(side - 1) {
                let i = y * side + x
                let c = Double(gray[i])
                let lap = Double(gray[i - 1]) + Double(gray[i + 1]) + Double(gray[i - side]) + Double(gray[i + side]) - 4 * c
                lapSum += lap; lapSq += lap * lap; count += 1
            }
        }
        let mean = lapSum / max(count, 1)
        let variance = lapSq / max(count, 1) - mean * mean
        return GrayStats(laplacianVariance: variance, meanLuminance: sum / n / 255.0, clippedFraction: Double(clipped) / n)
    }

    static func meanAbsDiff(_ a: [UInt8], _ b: [UInt8]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var s = 0
        for i in 0..<a.count { s += abs(Int(a[i]) - Int(b[i])) }
        return Double(s) / Double(a.count) / 255.0
    }

    static func cgImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
        let ci = CIImage(cvPixelBuffer: pixelBuffer)
        return sharedCIContext.createCGImage(ci, from: ci.extent)
    }
    private static let sharedCIContext = CIContext(options: [.useSoftwareRenderer: false])
}
import CoreImage
