import XCTest
@testable import AutreyMillSentry

final class PriorityScoreTests: XCTestCase {
    func input(patch: PatchSize = .few, nearby: Int = 0, creek: Double? = 10, conf: Double = 0.95, expert: Bool = false, age: Double = 1, status: ReportStatus = .new, agg: Double = 1.0) -> RankingInput {
        RankingInput(patchSize: patch, nearbyReportCount: nearby, distanceToCreekMeters: creek, confidence: conf, needsExpertReview: expert, ageDays: age, status: status, speciesAggressiveness: agg)
    }
    func testBestCaseIsNearOneHundred() {
        let s = PriorityScore.score(input(conf: 1.0))
        XCTAssertEqual(s.total, 100, accuracy: 0.01)
        XCTAssertEqual(s.factors.map(\.maxPoints).reduce(0, +), 100, accuracy: 0.01)
    }
    func testClosedReportsScoreZero() {
        XCTAssertEqual(PriorityScore.score(input(status: .treated)).total, 0)
        XCTAssertEqual(PriorityScore.score(input(status: .dismissed)).total, 0)
        XCTAssertGreaterThan(PriorityScore.score(input(status: .confirmed)).total, 0)
    }
    func testSmallPatchOutranksLargeStand() {
        XCTAssertGreaterThan(PriorityScore.score(input(patch: .few)).total, PriorityScore.score(input(patch: .large)).total)
    }
    func testIsolatedOutranksClustered() {
        XCTAssertGreaterThan(PriorityScore.score(input(nearby: 0)).total, PriorityScore.score(input(nearby: 5)).total)
    }
    func testCreekProximityFades() {
        let near = PriorityScore.score(input(creek: 5)).total
        let mid = PriorityScore.score(input(creek: 80)).total
        let far = PriorityScore.score(input(creek: 500)).total
        XCTAssertGreaterThan(near, mid); XCTAssertGreaterThan(mid, far)
        XCTAssertEqual(near - far, Config.ranking.creekProximity, accuracy: 0.11)
    }
    func testExpertReviewCapsConfidence() {
        XCTAssertLessThan(PriorityScore.score(input(conf: 0.95, expert: true)).total, PriorityScore.score(input(conf: 0.95)).total)
    }
    func testRecencyDecaysToFloor() {
        let fresh = PriorityScore.score(input(age: 0)).total
        let old = PriorityScore.score(input(age: 200)).total
        XCTAssertEqual(fresh - old, Config.ranking.recency * 0.7, accuracy: 0.11)
    }
    func testAggressivenessWeight() {
        XCTAssertEqual(PriorityScore.score(input(agg: 1)).total - PriorityScore.score(input(agg: 0)).total, Config.ranking.speciesAggressiveness, accuracy: 0.11)
    }
    func testNoCreekDataGivesZeroCreekPoints() {
        let f = PriorityScore.score(input(creek: nil)).factors.first { $0.name == "Near the creek" }
        XCTAssertEqual(f?.points, 0)
    }
    func testAlwaysWithinRange() {
        for p in PatchSize.allCases { for n in [0, 1, 3, 10] { for c in [0.0, 0.5, 1.0] { for a in [0.0, 30.0, 400.0] {
            let s = PriorityScore.score(input(patch: p, nearby: n, conf: c, age: a)).total
            XCTAssertGreaterThanOrEqual(s, 0); XCTAssertLessThanOrEqual(s, 100)
        } } } }
    }
}
