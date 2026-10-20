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
    /// Live-frame pass at two scales when the classifier supports it (full frame + `focus`, the salient region in Vision
    /// coordinates, or a centre region when nil); defaults to the single pass.
    func classifyLive(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, focus: CGRect?) throws -> ClassificationResult
}

extension PlantClassifying {
    func classifyLive(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, focus: CGRect?) throws -> ClassificationResult {
        try classify(pixelBuffer: pixelBuffer, orientation: orientation)
    }
}

extension CoreMLClassifier {
    func classifyLive(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, focus: CGRect?) throws -> ClassificationResult {
        try classifyMultiScale(pixelBuffer: pixelBuffer, orientation: orientation, focus: focus)
    }
}

enum ClassifierFactory {
    /// Real Core ML model when bundled, otherwise the mock (and always the mock under UI tests).
    static func make(catalog: SpeciesCatalog) -> PlantClassifying {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-mockScan"), i + 1 < args.count {
            return MockClassifier(scenario: MockClassifier.Scenario(rawValue: args[i + 1]) ?? .cycle, catalog: catalog)
        }
        if let primary = CoreMLClassifier() {
            if let secondary = CoreMLClassifier(resourceName: "InvasiveClassifierB") { return EnsembleClassifier(primary: primary, secondary: secondary) }
            return primary
        }
        return MockClassifier(scenario: .cycle, catalog: catalog)
    }
}

// MARK: - Core ML through Vision

/// Works with both model shapes: the two-output model (`probs` + `embedding`, labels from labels.json) and the
/// older single-output classifier model.
final class CoreMLClassifier: PlantClassifying {
    let modelVersion: String
    let isMock = false
    private let vnModel: VNCoreMLModel
    private let labels: [String]

    init?(resourceName: String = "InvasiveClassifier") {
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "mlmodelc") else { return nil }
        let config = MLModelConfiguration()
        #if targetEnvironment(simulator)
        config.computeUnits = .cpuOnly      // the simulator's GPU backend rejects this model; CPU is fine for tests
        #else
        config.computeUnits = .all
        #endif
        guard let model = try? MLModel(contentsOf: url, configuration: config), let vn = try? VNCoreMLModel(for: model) else { return nil }
        vnModel = vn
        let meta = model.modelDescription.metadata[.versionString] as? String
        modelVersion = meta ?? (model.modelDescription.metadata[.description] as? String) ?? "coreml"
        if let lurl = Bundle.main.url(forResource: "labels", withExtension: "json"), let data = try? Data(contentsOf: lurl),
           let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let l = obj["labels"] as? [String] {
            labels = l
        } else {
            labels = []
        }
    }

    func classify(_ image: CGImage, orientation: CGImagePropertyOrientation) throws -> ClassificationResult {
        try run(handler: VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:]))
    }

    func classify(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> ClassificationResult {
        try run(handler: VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:]))
    }

    /// Two looks at one live frame: the full centre crop and a tighter centre region (small, far-away subjects), averaged.
    /// Vision runs the second pass on a region of interest, so the cost is one extra model call, no extra copies.
    func classifyMultiScale(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, focus: CGRect? = nil, innerFraction: CGFloat = 0.68) throws -> ClassificationResult {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        let full = try run(handler: handler)
        let inset = (1 - innerFraction) / 2
        let region = focus ?? CGRect(x: inset, y: inset, width: innerFraction, height: innerFraction)
        let inner = try run(handler: handler, region: region)
        guard !inner.probabilities.isEmpty else { return full }
        return ClassificationResult(probabilities: Evidence.average([full.probabilities, inner.probabilities]), modelVersion: full.modelVersion, embedding: full.embedding)
    }

    private func run(handler: VNImageRequestHandler, region: CGRect? = nil) throws -> ClassificationResult {
        let request = VNCoreMLRequest(model: vnModel)
        request.imageCropAndScaleOption = .centerCrop
        if let region { request.regionOfInterest = region }
        try handler.perform([request])
        if let obs = request.results as? [VNClassificationObservation], !obs.isEmpty {
            let probs = obs.map { ClassProbability(label: $0.identifier, probability: Double($0.confidence)) }.sorted { $0.probability > $1.probability }
            return ClassificationResult(probabilities: probs, modelVersion: modelVersion)
        }
        var probs: [ClassProbability] = []
        var embedding: [Float]? = nil
        for o in (request.results as? [VNCoreMLFeatureValueObservation]) ?? [] {
            guard let arr = o.featureValue.multiArrayValue else { continue }
            let values = Self.floats(arr)
            if o.featureName == "embedding" {
                embedding = values
            } else if o.featureName == "probs" || probs.isEmpty {
                guard labels.count == values.count else { continue }
                probs = zip(labels, values).map { ClassProbability(label: $0, probability: Double($1)) }.sorted { $0.probability > $1.probability }
            }
        }
        return ClassificationResult(probabilities: probs, modelVersion: modelVersion, embedding: embedding)
    }

    private static func floats(_ arr: MLMultiArray) -> [Float] {
        // Outputs can arrive as float16 (neural engine / FP16 models), float32 or double. MLShapedArray must be
        // initialised with the matching scalar type or it traps.
        switch arr.dataType {
        case .float16:
            return MLShapedArray<Float16>(arr).scalars.map { Float($0) }
        case .float32:
            return MLShapedArray<Float>(arr).scalars
        case .double:
            return MLShapedArray<Double>(arr).scalars.map { Float($0) }
        default:
            return (0..<arr.count).map { arr[$0].floatValue }
        }
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
