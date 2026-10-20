import Foundation
import CoreGraphics
import CoreVideo
import ImageIO

/// Two Core ML models averaged on the captured still (where accuracy matters), one model live (where speed matters).
/// The primary model also supplies the embedding for the similarity gate and the live frames.
final class EnsembleClassifier: PlantClassifying {
    let primary: CoreMLClassifier
    let secondary: CoreMLClassifier
    let modelVersion: String
    let isMock = false

    init(primary: CoreMLClassifier, secondary: CoreMLClassifier) {
        self.primary = primary
        self.secondary = secondary
        self.modelVersion = "\(primary.modelVersion)+\(secondary.modelVersion)"
    }

    func classify(_ image: CGImage, orientation: CGImagePropertyOrientation) throws -> ClassificationResult {
        let a = try primary.classify(image, orientation: orientation)
        guard let b = try? secondary.classify(image, orientation: orientation), !b.probabilities.isEmpty else { return a }
        let avg = Evidence.average([a.probabilities, b.probabilities])
        return ClassificationResult(probabilities: avg, modelVersion: modelVersion, embedding: a.embedding)
    }

    func classify(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> ClassificationResult {
        try primary.classify(pixelBuffer: pixelBuffer, orientation: orientation)
    }

    func classifyLive(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> ClassificationResult {
        try primary.classifyMultiScale(pixelBuffer: pixelBuffer, orientation: orientation)
    }
}
