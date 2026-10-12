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

    static func decide(quality: QualityMetrics,
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

        switch catalog.tier(of: top.label) {
        case .tier1:
            if top.probability >= t.confirmMin(for: top.label) && margin >= t.confirmMinMargin {
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

/// Requires agreement over a short window of live frames before the UI says "locked on".
struct LockOnTracker: Sendable {
    enum State: Equatable, Sendable {
        case idle
        case tracking(label: String, agree: Int, needed: Int)
        case locked(label: String, meanProbability: Double)
    }
    private(set) var history: [ClassProbability] = []
    let window: Int
    let agreeCount: Int
    let meanProbability: Double

    init(thresholds t: ScanThresholds = Config.scan) {
        window = t.lockOnWindow; agreeCount = t.lockOnAgreeCount; meanProbability = t.lockOnMeanProbability
    }

    mutating func reset() { history.removeAll() }

    mutating func push(_ top: ClassProbability?) -> State {
        guard let top else { history.removeAll(); return .idle }
        history.append(top)
        if history.count > window { history.removeFirst(history.count - window) }
        let same = history.filter { $0.label == top.label }
        let mean = same.map(\.probability).reduce(0, +) / Double(same.count)
        if same.count >= agreeCount && mean >= meanProbability { return .locked(label: top.label, meanProbability: mean) }
        return .tracking(label: top.label, agree: same.count, needed: agreeCount)
    }
}
