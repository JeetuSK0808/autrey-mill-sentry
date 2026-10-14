import Foundation

struct ClassProbability: Codable, Equatable, Sendable, Identifiable {
    var id: String { label }
    var label: String
    var probability: Double
}

struct ClassificationResult: Codable, Equatable, Sendable {
    /// Sorted by probability, descending. Calibrated probabilities (temperature scaled).
    var probabilities: [ClassProbability]
    var modelVersion: String
    /// L2-normalised penultimate features, when the model provides them (used by the similarity gate).
    var embedding: [Float]? = nil

    var top: ClassProbability? { probabilities.first }
    var second: ClassProbability? { probabilities.count > 1 ? probabilities[1] : nil }
    var top3: [ClassProbability] { Array(probabilities.prefix(3)) }
    func probability(of label: String) -> Double { probabilities.first { $0.label == label }?.probability ?? 0 }
}

/// Frame quality measurements. All values are normalised so thresholds are readable.
struct QualityMetrics: Codable, Equatable, Sendable {
    var sharpness: Double = 0          // variance of Laplacian, higher is sharper
    var meanLuminance: Double = 0.5    // 0...1
    var clippedFraction: Double = 0    // fraction of near-white pixels
    var subjectFraction: Double = 0.5  // saliency box area / frame area
    var subjectTouchesEdges: Bool = false
    var personDetected: Bool = false
    var motion: Double = 0             // mean abs frame difference 0...1

    static let perfect = QualityMetrics(sharpness: 500, meanLuminance: 0.5, clippedFraction: 0, subjectFraction: 0.5, subjectTouchesEdges: false, personDetected: false, motion: 0)
}

enum RescanReason: String, Codable, CaseIterable, Sendable {
    case blurry, tooDark, overexposed, tooFar, tooClose, noPlantFound, personInFrame, ambiguous

    var title: String {
        switch self {
        case .blurry: return "Hold steady"
        case .tooDark: return "Too dark"
        case .overexposed: return "Too bright"
        case .tooFar: return "Move closer"
        case .tooClose: return "Step back a little"
        case .noPlantFound: return "No plant in view"
        case .personInFrame: return "Please retake without people"
        case .ambiguous: return "Not sure yet"
        }
    }

    /// Kind, specific instruction. The live guidance uses `liveHint`, the result screen uses `instruction`.
    var instruction: String {
        switch self {
        case .blurry: return "The photo is blurry. Brace your elbows, hold still for a second, then tap the shutter."
        case .tooDark: return "There is not enough light to see the leaves. Find a brighter spot or wait for a break in the clouds."
        case .overexposed: return "Bright sky or sun is washing out the plant. Shade the leaves with your body or move so the sky is out of frame."
        case .tooFar: return "The plant is too small in the frame. Move closer so the leaves fill most of the screen."
        case .tooClose: return "You are so close the plant overflows the frame. Step back a little so a whole leaf cluster fits."
        case .noPlantFound: return "We did not find a plant in this shot. Point the camera at leaves, flowers or berries."
        case .personInFrame: return "Please retake without people in the shot. Do not photograph people, especially children."
        case .ambiguous: return "We could not tell what this is. Try a different part of the plant."
        }
    }

    var liveHint: String {
        switch self {
        case .blurry: return "Hold steady"
        case .tooDark: return "Too dark, find some light"
        case .overexposed: return "Too bright, shade the leaves"
        case .tooFar: return "Move closer to the leaves"
        case .tooClose: return "Step back a little"
        case .noPlantFound: return "Point at leaves or flowers"
        case .personInFrame: return "No people in the shot, please"
        case .ambiguous: return "Try another angle"
        }
    }
}

enum ScanOutcome: Equatable, Sendable {
    case confirmedInvasive(species: String, confidence: Double)
    case possibleInvasive(candidates: [ClassProbability])
    case looksNative(label: String?, confidence: Double)
    case rescan(RescanReason)

    var isRescan: Bool { if case .rescan = self { return true } else { return false } }
}

/// Pure decision logic. No UI, no model, fully unit tested.
enum ScanDecision {
    /// Returns a reason to rescan if the frame fails a quality gate. Order matters: the most actionable problem first.
    static func qualityGate(_ q: QualityMetrics, thresholds t: ScanThresholds = Config.scan) -> RescanReason? {
        if q.personDetected { return .personInFrame }
        if q.meanLuminance < t.minMeanLuminance { return .tooDark }
        if q.meanLuminance > t.maxMeanLuminance || q.clippedFraction > t.maxClippedFraction { return .overexposed }
        if q.motion > t.maxMotion { return .blurry }
        if q.sharpness < t.minSharpness { return .blurry }
        if q.subjectFraction < t.minSubjectFraction { return .tooFar }
        if q.subjectFraction > t.maxSubjectFraction && q.subjectTouchesEdges { return .tooClose }
        return nil
    }

    /// `similarity` returns the cosine similarity of the photo's embedding to a class centroid and that class's floor,
    /// or nil when no embedding data exists. Below the floor the call is downgraded one level
    /// (confirmed -> possible, possible -> "we can't recognise this one").
    static func decide(quality: QualityMetrics,
                       classification: ClassificationResult,
                       catalog: SpeciesCatalog,
                       thresholds t: ScanThresholds = Config.scan,
                       similarity: ((String) -> (value: Double, floor: Double)?)? = nil) -> ScanOutcome {
        let raw = decideRaw(quality: quality, classification: classification, catalog: catalog, thresholds: t)
        guard t.embeddingGateEnabled, let similarity else { return raw }
        switch raw {
        case .confirmedInvasive(let s, _):
            if let sim = similarity(s), sim.value < sim.floor {
                let cands = classification.top3.filter { catalog.tier(of: $0.label) == .tier1 || catalog.tier(of: $0.label) == .tier2 }
                return .possibleInvasive(candidates: cands.isEmpty ? [classification.top!] : cands)
            }
            return raw
        case .possibleInvasive(let cands):
            if let first = cands.first, let sim = similarity(first.label), sim.value < sim.floor - 0.05 { return .rescan(.ambiguous) }
            return raw
        default:
            return raw
        }
    }

    static func decideRaw(quality: QualityMetrics,
                          classification: ClassificationResult,
                          catalog: SpeciesCatalog,
                          thresholds t: ScanThresholds = Config.scan) -> ScanOutcome {
        if let gate = qualityGate(quality, thresholds: t) { return .rescan(gate) }
        guard let top = classification.top else { return .rescan(.ambiguous) }
        let secondProb = classification.second?.probability ?? 0
        let margin = top.probability - secondProb

        // Anything that is not a plant, with enough confidence, is a framing problem, not a species.
        if top.label == "not_plant" && top.probability >= t.notPlantMinProbability { return .rescan(.noPlantFound) }

        // Invasive candidates among the top 3 that are plausible on their own.
        let invasiveCandidates = classification.top3.filter { catalog.tier(of: $0.label) == .tier1 || catalog.tier(of: $0.label) == .tier2 }
            .filter { $0.probability >= t.possibleMinProbability }

        let entropy = Evidence.normalisedEntropy(classification.probabilities)
        switch catalog.tier(of: top.label) {
        case .tier1:
            if top.probability >= t.confirmMin(for: top.label) && margin >= t.confirmMinMargin && entropy <= t.maxEntropyForConfirm {
                return .confirmedInvasive(species: top.label, confidence: top.probability)
            }
            if top.probability >= t.possibleMinProbability { return .possibleInvasive(candidates: invasiveCandidates.isEmpty ? [top] : invasiveCandidates) }
            return .rescan(.ambiguous)
        case .tier2:
            if top.probability >= t.possibleMinProbability { return .possibleInvasive(candidates: invasiveCandidates.isEmpty ? [top] : invasiveCandidates) }
            return .rescan(.ambiguous)
        case .native, .other:
            // A plausible invasive runner-up wins over a weak "native" call: staff should look.
            if !invasiveCandidates.isEmpty && top.probability < t.nativeMinProbability { return .possibleInvasive(candidates: invasiveCandidates) }
            if top.probability >= t.nativeMinProbability {
                return .looksNative(label: top.label == "other_plant" || top.label == "not_plant" ? nil : top.label, confidence: top.probability)
            }
            if !invasiveCandidates.isEmpty { return .possibleInvasive(candidates: invasiveCandidates) }
            return .rescan(.ambiguous)
        }
    }

    /// A specific tip for what to photograph next, based on the best candidate species.
    static func tip(for reason: RescanReason, candidate: String?, catalog: SpeciesCatalog) -> String {
        if let c = candidate, let s = catalog.species(for: c), !s.whatToPhotograph.isEmpty {
            return "If this might be \(s.displayName): \(s.whatToPhotograph)"
        }
        switch reason {
        case .ambiguous, .tooFar, .tooClose: return "Try a close-up of one leaf, then the way leaves are arranged on the stem, then flowers or berries."
        default: return "Good shots: one leaf close up, the leaf arrangement on the stem, flowers or berries, then the whole plant."
        }
    }
}

/// Combines several probability vectors (test-time augmentation passes, live evidence) into one, renormalised.
enum Evidence {
    static func average(_ distributions: [[ClassProbability]], weights: [Double]? = nil) -> [ClassProbability] {
        guard !distributions.isEmpty else { return [] }
        let w = weights ?? Array(repeating: 1.0, count: distributions.count)
        var sums: [String: Double] = [:]
        var total = 0.0
        for (d, wi) in zip(distributions, w) {
            for c in d { sums[c.label, default: 0] += c.probability * wi }
            total += wi
        }
        return sums.map { ClassProbability(label: $0.key, probability: $0.value / max(total, 1e-9)) }.sorted { $0.probability > $1.probability }
    }

    /// Entropy of the whole distribution, normalised 0...1 by log(max(n, 10)). High means "the model does not know".
    static func normalisedEntropy(_ d: [ClassProbability]) -> Double {
        let p = d.map(\.probability)
        let s = p.reduce(0, +)
        guard s > 0, p.count > 1 else { return 0 }
        let h = -p.map { $0 / s }.filter { $0 > 0 }.map { $0 * log($0) }.reduce(0, +)
        return h / log(Double(max(p.count, 10)))
    }
}

/// Requires agreement over a short window of live frames before the UI says "locked on".
struct LockOnTracker: Sendable {
    enum State: Equatable, Sendable {
        case idle
        case tracking(label: String, agree: Int, needed: Int)
        case locked(label: String, meanProbability: Double)
    }
    private(set) var history: [ClassProbability] = []
    private(set) var recentDistributions: [[ClassProbability]] = []
    let window: Int
    let agreeCount: Int
    let meanProbability: Double

    init(thresholds t: ScanThresholds = Config.scan) {
        window = t.lockOnWindow; agreeCount = t.lockOnAgreeCount; meanProbability = t.lockOnMeanProbability
    }

    mutating func reset() { history.removeAll(); recentDistributions.removeAll() }

    /// Mean of the recent live distributions (top classes only), used as extra evidence for the captured still.
    func liveEvidence(minFrames: Int = 4) -> [ClassProbability]? {
        guard recentDistributions.count >= minFrames else { return nil }
        var sums: [String: Double] = [:]
        for d in recentDistributions { for c in d { sums[c.label, default: 0] += c.probability } }
        let n = Double(recentDistributions.count)
        return sums.map { ClassProbability(label: $0.key, probability: $0.value / n) }.sorted { $0.probability > $1.probability }
    }

    mutating func push(_ top: ClassProbability?, distribution: [ClassProbability] = []) -> State {
        guard let top else { history.removeAll(); recentDistributions.removeAll(); return .idle }
        history.append(top)
        if history.count > window { history.removeFirst(history.count - window) }
        if !distribution.isEmpty {
            recentDistributions.append(Array(distribution.prefix(5)))
            if recentDistributions.count > window { recentDistributions.removeFirst(recentDistributions.count - window) }
        }
        let same = history.filter { $0.label == top.label }
        let mean = same.map(\.probability).reduce(0, +) / Double(same.count)
        if same.count >= agreeCount && mean >= meanProbability { return .locked(label: top.label, meanProbability: mean) }
        return .tracking(label: top.label, agree: same.count, needed: agreeCount)
    }
}
