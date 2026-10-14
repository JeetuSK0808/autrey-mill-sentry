import Foundation

/// Every tunable number in one place. Values marked "tuned" are overwritten at launch by
/// `Resources/thresholds.json`, which is written by `model/tune_thresholds.py` from held-out data.
enum Config {
    static let appName = "Autrey Mill Sentry"
    static let displayName = "Mill Sentry"
    static let credit = "A student project by Jeetu SK, built for Autrey Mill Nature Preserve."

    /// TODO_RANGER_EMAIL: placeholder until preserve staff give an address. Never invent one.
    static let rangerEmail = "TODO_RANGER_EMAIL"
    static var rangerEmailIsSet: Bool { rangerEmail.contains("@") }

    // Preserve geography (centre of the OSM park polygon, way 589352774)
    static let preserveCenter = GeoPoint(latitude: 34.0199, longitude: -84.2326)
    static let geofenceBufferMeters = 60.0        // inside the boundary plus this buffer counts as "at the preserve"
    static let nearPreserveHintMeters = 400.0     // "you're X m away" is shown within this distance
    static let mapPanLimitMeters = 1500.0         // camera bounds around the preserve

    // Reports
    static let duplicateRadiusMeters = 10.0
    static let duplicateWindowDays = 7
    static let isolationRadiusMeters = 30.0       // "other reports within about 30 m" for the ranking
    static let goodAccuracyMeters = 30.0
    static let locationWaitSeconds: TimeInterval = 6
    static let exportRoundingDecimals = 3         // 0.001 deg is about 100 m: used for the "round on export" option

    /// Tuned on held-out validation data when `thresholds.json` is bundled; defaults otherwise.
    static let scan: ScanThresholds = {
        if let url = Bundle.main.url(forResource: "thresholds", withExtension: "json"), let data = try? Data(contentsOf: url),
           let t = try? JSONDecoder().decode(ScanThresholds.self, from: data) { return t }
        return .defaults
    }()
    static let ranking = RankingWeights.defaults
}

/// Scanner thresholds. Initial values; `thresholds.json` (from real validation data) overrides them.
struct ScanThresholds: Codable, Equatable {
    // Decision
    var confirmMinProbability: Double = 0.80      // Tier 1 top class must be at least this calibrated probability
    var confirmMinMargin: Double = 0.30           // and lead the runner-up by this much
    var possibleMinProbability: Double = 0.55     // below this nothing is claimed; the user may "report anyway"
    var nativeMinProbability: Double = 0.60
    var notPlantMinProbability: Double = 0.50
    var perClassConfirmMin: [String: Double] = [:] // optional per-species overrides, tuned on validation data
    var maxEntropyForConfirm: Double = 0.45       // normalised top-10 entropy above this: never "confirmed"
    var embeddingGateEnabled: Bool = true         // downgrade calls whose photo is far from the species' training centroid
    var liveEvidenceWeight: Double = 0.35         // weight of the live-frame mean when fusing with the still

    // Lock-on over a short window of live frames
    var lockOnWindow: Int = 8
    var lockOnAgreeCount: Int = 5
    var lockOnMeanProbability: Double = 0.60

    // Quality gates (frame-level)
    var minSharpness: Double = 40.0               // variance of Laplacian on a 256 px grey copy
    var minMeanLuminance: Double = 0.18           // 0...1
    var maxMeanLuminance: Double = 0.90
    var maxClippedFraction: Double = 0.25         // fraction of pixels at the top of the range
    var minSubjectFraction: Double = 0.10         // saliency box area / frame area
    var maxSubjectFraction: Double = 0.97
    var maxMotion: Double = 0.12                  // mean abs difference between consecutive frames, 0...1

    static let defaults = ScanThresholds()

    func confirmMin(for label: String) -> Double { perClassConfirmMin[label] ?? confirmMinProbability }
}

/// Weights of the transparent priority score (sum is 100). Documented in docs/RANKING.md.
struct RankingWeights: Codable, Equatable {
    var patchSize: Double = 25        // small, isolated patches first: early detection
    var isolation: Double = 15
    var creekProximity: Double = 20   // riparian corridors spread seeds downstream
    var confidence: Double = 15
    var recency: Double = 10
    var speciesAggressiveness: Double = 15
    var creekFullPointsWithinMeters: Double = 15
    var creekZeroPointsBeyondMeters: Double = 150
    var recencyFullPointsWithinDays: Double = 7
    var recencyFloorAtDays: Double = 90
    static let defaults = RankingWeights()
}
