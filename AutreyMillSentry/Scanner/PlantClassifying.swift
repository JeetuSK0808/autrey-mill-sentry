import Foundation
import CoreGraphics
import CoreML
import Vision
import ImageIO

/// The classifier sits behind this protocol so the UI and tests work before the real model exists.
protocol PlantClassifying: AnyObject {
    var modelVersion: String { get }
    var isMock: Bool { get }
    func classify(_ image: CGImage, orientation: CGImagePropertyOrientation) throws -> ClassificationResult
    func classify(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> ClassificationResult
}

enum ClassifierFactory {
    /// Real Core ML model when bundled, otherwise the mock (and always the mock under UI tests).
    static func make(catalog: SpeciesCatalog) -> PlantClassifying {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-mockScan"), i + 1 < args.count {
            return MockClassifier(scenario: MockClassifier.Scenario(rawValue: args[i + 1]) ?? .cycle, catalog: catalog)
        }
        if let real = CoreMLClassifier() { return real }
        return MockClassifier(scenario: .cycle, catalog: catalog)
    }
}

// MARK: - Core ML through Vision

final class CoreMLClassifier: PlantClassifying {
    let modelVersion: String
    let isMock = false
    private let vnModel: VNCoreMLModel

    init?() {
        guard let url = Bundle.main.url(forResource: "InvasiveClassifier", withExtension: "mlmodelc") else { return nil }
        let config = MLModelConfiguration()
        config.computeUnits = .all
        guard let model = try? MLModel(contentsOf: url, configuration: config), let vn = try? VNCoreMLModel(for: model) else { return nil }
        vnModel = vn
        let meta = model.modelDescription.metadata[.versionString] as? String
        modelVersion = meta ?? (model.modelDescription.metadata[.description] as? String) ?? "coreml"
    }

    func classify(_ image: CGImage, orientation: CGImagePropertyOrientation) throws -> ClassificationResult {
        try run(handler: VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:]))
    }

    func classify(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> ClassificationResult {
        try run(handler: VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:]))
    }

    private func run(handler: VNImageRequestHandler) throws -> ClassificationResult {
        let request = VNCoreMLRequest(model: vnModel)
        request.imageCropAndScaleOption = .centerCrop
        try handler.perform([request])
        let obs = (request.results as? [VNClassificationObservation]) ?? []
        let probs = obs.map { ClassProbability(label: $0.identifier, probability: Double($0.confidence)) }
            .sorted { $0.probability > $1.probability }
        return ClassificationResult(probabilities: probs, modelVersion: modelVersion)
    }
}

// MARK: - Mock

/// Deterministic stand-in. Scenarios drive UI tests and let the UI be built before training finishes.
final class MockClassifier: PlantClassifying {
    enum Scenario: String { case cycle, confirmed, possible, native, ambiguous, notPlant = "notplant", tier2 }
    let modelVersion = "mock-0.1"
    let isMock = true
    let scenario: Scenario
    private let catalog: SpeciesCatalog
    private let lock = NSLock()
    private var counter = 0

    init(scenario: Scenario, catalog: SpeciesCatalog) { self.scenario = scenario; self.catalog = catalog }

    func classify(_ image: CGImage, orientation: CGImagePropertyOrientation) throws -> ClassificationResult {
        result(seed: image.width &+ image.height &* 7)
    }
    func classify(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> ClassificationResult {
        result(seed: 0)
    }

    private func result(seed: Int) -> ClassificationResult {
        lock.lock(); counter += 1; let counter = self.counter; lock.unlock()
        let s: Scenario
        if scenario == .cycle {
            let all: [Scenario] = [.confirmed, .possible, .native, .ambiguous]
            s = all[abs(seed + counter / 40) % all.count]
        } else { s = scenario }
        let probs: [ClassProbability]
        switch s {
        case .confirmed, .cycle:
            probs = [.init(label: "ligustrum_sinense", probability: 0.91), .init(label: "viburnum_dentatum", probability: 0.04), .init(label: "other_plant", probability: 0.02)]
        case .possible:
            probs = [.init(label: "lonicera_japonica", probability: 0.52), .init(label: "lonicera_sempervirens", probability: 0.33), .init(label: "other_plant", probability: 0.08)]
        case .native:
            probs = [.init(label: "lonicera_sempervirens", probability: 0.84), .init(label: "lonicera_japonica", probability: 0.09), .init(label: "other_plant", probability: 0.03)]
        case .ambiguous:
            probs = [.init(label: "other_plant", probability: 0.31), .init(label: "hedera_helix", probability: 0.27), .init(label: "vinca_minor", probability: 0.22)]
        case .notPlant:
            probs = [.init(label: "not_plant", probability: 0.88), .init(label: "other_plant", probability: 0.07), .init(label: "hedera_helix", probability: 0.02)]
        case .tier2:
            let t2 = catalog.tier2.first?.label ?? "cirsium_vulgare"
            probs = [.init(label: t2, probability: 0.77), .init(label: "other_plant", probability: 0.12), .init(label: "rosa_multiflora", probability: 0.05)]
        }
        return ClassificationResult(probabilities: probs, modelVersion: modelVersion)
    }
}
