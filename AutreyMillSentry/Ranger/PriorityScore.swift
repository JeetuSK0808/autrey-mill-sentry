import Foundation

/// Inputs to the ranking, all plain values so it can be unit tested.
struct RankingInput: Sendable, Equatable {
    var patchSize: PatchSize
    var nearbyReportCount: Int          // other open reports within Config.isolationRadiusMeters
    var distanceToCreekMeters: Double?  // nil when no waterway data
    var confidence: Double              // calibrated top probability
    var needsExpertReview: Bool
    var ageDays: Double
    var status: ReportStatus
    var speciesAggressiveness: Double   // 0...1 from the catalog (GFC Dirty Dozen)
}

struct RankingFactor: Sendable, Equatable, Identifiable {
    var id: String { name }
    var name: String
    var points: Double
    var maxPoints: Double
    var reason: String
}

/// Transparent weighted sum, 0 to 100. Documented in docs/RANKING.md and the "How we rank" screen.
enum PriorityScore {
    static func score(_ r: RankingInput, weights w: RankingWeights = Config.ranking) -> (total: Double, factors: [RankingFactor]) {
        guard r.status.isOpen else {
            return (0, [RankingFactor(name: "Closed", points: 0, maxPoints: 100, reason: "Treated or dismissed reports are not ranked.")])
        }
        var f: [RankingFactor] = []

        let patch: Double = { switch r.patchSize { case .few: return 1.0; case .patch: return 0.6; case .large: return 0.2 } }()
        f.append(RankingFactor(name: "Patch size", points: patch * w.patchSize, maxPoints: w.patchSize,
                               reason: r.patchSize == .few ? "A few plants: cheapest to remove now." : r.patchSize == .patch ? "A patch: still manageable." : "A large stand: a bigger job, ranked lower for early detection."))

        let iso: Double = r.nearbyReportCount == 0 ? 1.0 : r.nearbyReportCount <= 2 ? 0.6 : 0.2
        f.append(RankingFactor(name: "Isolation", points: iso * w.isolation, maxPoints: w.isolation,
                               reason: r.nearbyReportCount == 0 ? "No other reports within \(Geo.feetDescription(Config.isolationRadiusMeters)): an isolated outpost." : "\(r.nearbyReportCount) other report(s) nearby: part of a bigger infestation."))

        var creek = 0.0
        var creekReason = "No waterway data."
        if let d = r.distanceToCreekMeters {
            if d <= w.creekFullPointsWithinMeters { creek = 1 }
            else if d >= w.creekZeroPointsBeyondMeters { creek = 0 }
            else { creek = 1 - (d - w.creekFullPointsWithinMeters) / (w.creekZeroPointsBeyondMeters - w.creekFullPointsWithinMeters) }
            creekReason = "\(Geo.roundedDistanceDescription(d)) from the creek. Water carries seeds downstream."
        }
        f.append(RankingFactor(name: "Near the creek", points: creek * w.creekProximity, maxPoints: w.creekProximity, reason: creekReason))

        let confRaw = r.needsExpertReview ? min(r.confidence, 0.3) : r.confidence
        let conf = max(0, min(1, (confRaw - 0.5) / 0.5))
        f.append(RankingFactor(name: "Model confidence", points: conf * w.confidence, maxPoints: w.confidence,
                               reason: r.needsExpertReview ? "Needs expert review, so confidence counts little." : "\(Int((r.confidence * 100).rounded()))% calibrated confidence."))

        var rec = 1.0
        if r.ageDays > w.recencyFullPointsWithinDays {
            let span = max(1, w.recencyFloorAtDays - w.recencyFullPointsWithinDays)
            rec = max(0.3, 1 - 0.7 * (r.ageDays - w.recencyFullPointsWithinDays) / span)
        }
        f.append(RankingFactor(name: "Recent and unaddressed", points: rec * w.recency, maxPoints: w.recency,
                               reason: r.ageDays <= w.recencyFullPointsWithinDays ? "Reported in the last week." : "\(Int(r.ageDays.rounded())) days old and still open."))

        let agg = max(0, min(1, r.speciesAggressiveness))
        f.append(RankingFactor(name: "Aggressive spreader", points: agg * w.speciesAggressiveness, maxPoints: w.speciesAggressiveness,
                               reason: "Weight \(String(format: "%.2f", agg)) from the Georgia Forestry Commission Dirty Dozen (acres occupied)."))

        let total = f.map(\.points).reduce(0, +)
        return ((total * 10).rounded() / 10, f)
    }
}
