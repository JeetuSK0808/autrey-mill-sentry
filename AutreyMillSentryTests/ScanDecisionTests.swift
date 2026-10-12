import XCTest
@testable import AutreyMillSentry

final class ScanDecisionTests: XCTestCase {
    let catalog = SpeciesCatalog(species: SpeciesCatalog.builtIn + [
        Species(label: "cirsium_vulgare", scientificName: "Cirsium vulgare", commonName: "Bull thistle", tier: .tier2, aggressiveness: 0.3, documentedAtPreserve: true,
                whyItMatters: "", howToRecognize: "", whatToPhotograph: "", lookAlike: nil, sourceURL: ""),
    ])
    let t = ScanThresholds.defaults

    func cls(_ pairs: [(String, Double)]) -> ClassificationResult {
        ClassificationResult(probabilities: pairs.map { ClassProbability(label: $0.0, probability: $0.1) }, modelVersion: "test")
    }

    // MARK: quality gates
    func testPersonBeatsEverything() {
        var q = QualityMetrics.perfect; q.personDetected = true; q.sharpness = 0
        XCTAssertEqual(ScanDecision.qualityGate(q, thresholds: t), .personInFrame)
    }
    func testTooDark() { var q = QualityMetrics.perfect; q.meanLuminance = 0.05; XCTAssertEqual(ScanDecision.qualityGate(q, thresholds: t), .tooDark) }
    func testOverexposedByLuminance() { var q = QualityMetrics.perfect; q.meanLuminance = 0.95; XCTAssertEqual(ScanDecision.qualityGate(q, thresholds: t), .overexposed) }
    func testOverexposedByClipping() { var q = QualityMetrics.perfect; q.clippedFraction = 0.4; XCTAssertEqual(ScanDecision.qualityGate(q, thresholds: t), .overexposed) }
    func testBlurryBySharpness() { var q = QualityMetrics.perfect; q.sharpness = 5; XCTAssertEqual(ScanDecision.qualityGate(q, thresholds: t), .blurry) }
    func testBlurryByMotion() { var q = QualityMetrics.perfect; q.motion = 0.3; XCTAssertEqual(ScanDecision.qualityGate(q, thresholds: t), .blurry) }
    func testTooFar() { var q = QualityMetrics.perfect; q.subjectFraction = 0.03; XCTAssertEqual(ScanDecision.qualityGate(q, thresholds: t), .tooFar) }
    func testTooClose() { var q = QualityMetrics.perfect; q.subjectFraction = 0.99; q.subjectTouchesEdges = true; XCTAssertEqual(ScanDecision.qualityGate(q, thresholds: t), .tooClose) }
    func testLargeSubjectNotTouchingEdgesIsFine() { var q = QualityMetrics.perfect; q.subjectFraction = 0.99; XCTAssertNil(ScanDecision.qualityGate(q, thresholds: t)) }
    func testPerfectPasses() { XCTAssertNil(ScanDecision.qualityGate(.perfect, thresholds: t)) }

    // MARK: outcomes
    func testConfirmedTier1() {
        let o = ScanDecision.decide(quality: .perfect, classification: cls([("ligustrum_sinense", 0.92), ("viburnum_dentatum", 0.04)]), catalog: catalog, thresholds: t)
        XCTAssertEqual(o, .confirmedInvasive(species: "ligustrum_sinense", confidence: 0.92))
    }
    func testTier1LowMarginIsPossible() {
        let o = ScanDecision.decide(quality: .perfect, classification: cls([("lonicera_japonica", 0.55), ("lonicera_sempervirens", 0.40)]), catalog: catalog, thresholds: t)
        if case .possibleInvasive(let c) = o { XCTAssertEqual(c.first?.label, "lonicera_japonica") } else { XCTFail("\(o)") }
    }
    func testTier1BelowConfirmThresholdIsPossible() {
        let o = ScanDecision.decide(quality: .perfect, classification: cls([("hedera_helix", 0.70), ("other_plant", 0.10)]), catalog: catalog, thresholds: t)
        if case .possibleInvasive = o {} else { XCTFail("\(o)") }
    }
    func testPerClassOverrideCanConfirmLower() {
        var tt = t; tt.perClassConfirmMin["hedera_helix"] = 0.65
        let o = ScanDecision.decide(quality: .perfect, classification: cls([("hedera_helix", 0.70), ("other_plant", 0.10)]), catalog: catalog, thresholds: tt)
        XCTAssertEqual(o, .confirmedInvasive(species: "hedera_helix", confidence: 0.70))
    }
    func testTier2NeverConfirmed() {
        let o = ScanDecision.decide(quality: .perfect, classification: cls([("cirsium_vulgare", 0.99), ("other_plant", 0.01)]), catalog: catalog, thresholds: t)
        if case .possibleInvasive(let c) = o { XCTAssertEqual(c.first?.label, "cirsium_vulgare") } else { XCTFail("\(o)") }
    }
    func testNativeLooksNative() {
        let o = ScanDecision.decide(quality: .perfect, classification: cls([("lonicera_sempervirens", 0.85), ("lonicera_japonica", 0.10)]), catalog: catalog, thresholds: t)
        XCTAssertEqual(o, .looksNative(label: "lonicera_sempervirens", confidence: 0.85))
    }
    func testWeakNativeWithPlausibleInvasiveGoesToExpert() {
        let o = ScanDecision.decide(quality: .perfect, classification: cls([("lonicera_sempervirens", 0.50), ("lonicera_japonica", 0.42)]), catalog: catalog, thresholds: t)
        if case .possibleInvasive(let c) = o { XCTAssertEqual(c.map(\.label), ["lonicera_japonica"]) } else { XCTFail("\(o)") }
    }
    func testOtherPlantIsNativeWithNoLabel() {
        let o = ScanDecision.decide(quality: .perfect, classification: cls([("other_plant", 0.80), ("hedera_helix", 0.05)]), catalog: catalog, thresholds: t)
        XCTAssertEqual(o, .looksNative(label: nil, confidence: 0.80))
    }
    func testNotPlantIsRescan() {
        let o = ScanDecision.decide(quality: .perfect, classification: cls([("not_plant", 0.9), ("other_plant", 0.05)]), catalog: catalog, thresholds: t)
        XCTAssertEqual(o, .rescan(.noPlantFound))
    }
    func testNothingConfidentIsAmbiguous() {
        let o = ScanDecision.decide(quality: .perfect, classification: cls([("other_plant", 0.30), ("hedera_helix", 0.25), ("vinca_minor", 0.20)]), catalog: catalog, thresholds: t)
        XCTAssertEqual(o, .rescan(.ambiguous))
    }
    func testQualityGateWinsOverClassifier() {
        var q = QualityMetrics.perfect; q.sharpness = 1
        let o = ScanDecision.decide(quality: q, classification: cls([("ligustrum_sinense", 0.99)]), catalog: catalog, thresholds: t)
        XCTAssertEqual(o, .rescan(.blurry))
    }
    func testEveryRescanReasonHasCopy() {
        for r in RescanReason.allCases { XCTAssertFalse(r.instruction.isEmpty); XCTAssertFalse(r.liveHint.isEmpty); XCTAssertFalse(r.title.isEmpty) }
    }
    func testTipNamesCandidateSpecies() {
        XCTAssertTrue(ScanDecision.tip(for: .ambiguous, candidate: "ligustrum_sinense", catalog: catalog).contains("Chinese privet"))
    }
}

final class LockOnTrackerTests: XCTestCase {
    func testLocksAfterAgreement() {
        var tr = LockOnTracker(thresholds: .defaults)
        var state: LockOnTracker.State = .idle
        for _ in 0..<4 { state = tr.push(ClassProbability(label: "hedera_helix", probability: 0.8)) }
        if case .tracking(_, let agree, let needed) = state { XCTAssertEqual(agree, 4); XCTAssertEqual(needed, 5) } else { XCTFail("\(state)") }
        state = tr.push(ClassProbability(label: "hedera_helix", probability: 0.8))
        XCTAssertEqual(state, .locked(label: "hedera_helix", meanProbability: 0.8))
    }
    func testLowProbabilityDoesNotLock() {
        var tr = LockOnTracker(thresholds: .defaults)
        var state: LockOnTracker.State = .idle
        for _ in 0..<8 { state = tr.push(ClassProbability(label: "hedera_helix", probability: 0.4)) }
        if case .locked = state { XCTFail("should not lock at 0.4") }
    }
    func testFlickerBreaksLock() {
        var tr = LockOnTracker(thresholds: .defaults)
        for _ in 0..<5 { _ = tr.push(ClassProbability(label: "a", probability: 0.9)) }
        var s: LockOnTracker.State = .idle
        for _ in 0..<4 { s = tr.push(ClassProbability(label: "b", probability: 0.9)) }
        if case .locked = s { XCTFail("4 of 8 should not lock") }
    }
    func testNilResets() {
        var tr = LockOnTracker(thresholds: .defaults)
        for _ in 0..<5 { _ = tr.push(ClassProbability(label: "a", probability: 0.9)) }
        XCTAssertEqual(tr.push(nil), .idle)
        XCTAssertTrue(tr.history.isEmpty)
    }
}
