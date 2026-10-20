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
    func testOverexposedByLuminance() { var q = QualityMetrics.perfect; q.meanLuminance = 0.97; XCTAssertEqual(ScanDecision.qualityGate(q, thresholds: t), .overexposed) }
    func testOverexposedByClipping() { var q = QualityMetrics.perfect; q.clippedFraction = 0.5; XCTAssertEqual(ScanDecision.qualityGate(q, thresholds: t), .overexposed) }
    func testBlurryBySharpness() { var q = QualityMetrics.perfect; q.sharpness = 5; XCTAssertEqual(ScanDecision.qualityGate(q, thresholds: t), .blurry) }
    func testBlurryByMotion() { var q = QualityMetrics.perfect; q.motion = 0.4; XCTAssertEqual(ScanDecision.qualityGate(q, thresholds: t), .blurry) }
    func testTooFar() { var q = QualityMetrics.perfect; q.subjectFraction = 0.03; XCTAssertEqual(ScanDecision.qualityGate(q, thresholds: t), .tooFar) }
    func testTooClose() { var q = QualityMetrics.perfect; q.subjectFraction = 0.999; q.subjectTouchesEdges = true; XCTAssertEqual(ScanDecision.qualityGate(q, thresholds: t), .tooClose) }
    func testLargeSubjectNotTouchingEdgesIsFine() { var q = QualityMetrics.perfect; q.subjectFraction = 0.999; XCTAssertNil(ScanDecision.qualityGate(q, thresholds: t)) }
    func testPerfectPasses() { XCTAssertNil(ScanDecision.qualityGate(.perfect, thresholds: t)) }

    // MARK: outcomes
    func testConfirmedTier1() {
        let o = ScanDecision.decide(quality: .perfect, classification: cls([("ligustrum_sinense", 0.92), ("viburnum_dentatum", 0.04)]), catalog: catalog, thresholds: t)
        XCTAssertEqual(o, .confirmedInvasive(species: "ligustrum_sinense", confidence: 0.92))
    }
    func testTier1LowMarginIsPossible() {
        let o = ScanDecision.decide(quality: .perfect, classification: cls([("lonicera_japonica", 0.60), ("lonicera_sempervirens", 0.35)]), catalog: catalog, thresholds: t)
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
        let o = ScanDecision.decide(quality: .perfect, classification: cls([("lonicera_sempervirens", 0.50), ("lonicera_japonica", 0.56)]), catalog: catalog, thresholds: t)
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
    func testHardGateWinsOverClassifier() {
        var q = QualityMetrics.perfect; q.personDetected = true
        let o = ScanDecision.decide(quality: q, classification: cls([("ligustrum_sinense", 0.99)]), catalog: catalog, thresholds: t)
        XCTAssertEqual(o, .rescan(.personInFrame))
    }
    func testSoftGateDoesNotBlockAConfidentResult() {
        var q = QualityMetrics.perfect; q.sharpness = 1; q.subjectFraction = 0.02
        let o = ScanDecision.decide(quality: q, classification: cls([("ligustrum_sinense", 0.99), ("other_plant", 0.005)]), catalog: catalog, thresholds: t)
        XCTAssertEqual(o, .confirmedInvasive(species: "ligustrum_sinense", confidence: 0.99))
    }
    func testSoftGateExplainsAnAmbiguousResult() {
        var q = QualityMetrics.perfect; q.subjectFraction = 0.02
        let o = ScanDecision.decide(quality: q, classification: cls([("other_plant", 0.30), ("hedera_helix", 0.25)]), catalog: catalog, thresholds: t)
        XCTAssertEqual(o, .rescan(.tooFar))
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

final class EmbeddingGateTests: XCTestCase {
    let catalog = SpeciesCatalog(species: SpeciesCatalog.builtIn)
    let t = ScanThresholds.defaults
    func cls(_ pairs: [(String, Double)]) -> ClassificationResult {
        ClassificationResult(probabilities: pairs.map { ClassProbability(label: $0.0, probability: $0.1) }, modelVersion: "test", embedding: [1, 0, 0])
    }
    func testFarFromCentroidDowngradesConfirmedToPossible() {
        let c = cls([("ligustrum_sinense", 0.95), ("viburnum_dentatum", 0.02)])
        let o = ScanDecision.decide(quality: .perfect, classification: c, catalog: catalog, thresholds: t, similarity: { _ in (value: 0.40, floor: 0.62) })
        if case .possibleInvasive(let cands) = o { XCTAssertEqual(cands.first?.label, "ligustrum_sinense") } else { XCTFail("\(o)") }
    }
    func testCloseToCentroidKeepsConfirmed() {
        let c = cls([("ligustrum_sinense", 0.95), ("viburnum_dentatum", 0.02)])
        let o = ScanDecision.decide(quality: .perfect, classification: c, catalog: catalog, thresholds: t, similarity: { _ in (value: 0.80, floor: 0.62) })
        XCTAssertEqual(o, .confirmedInvasive(species: "ligustrum_sinense", confidence: 0.95))
    }
    func testVeryFarPossibleBecomesUnknown() {
        let c = cls([("hedera_helix", 0.55), ("other_plant", 0.2)])
        let o = ScanDecision.decide(quality: .perfect, classification: c, catalog: catalog, thresholds: t, similarity: { _ in (value: 0.30, floor: 0.62) })
        XCTAssertEqual(o, .rescan(.ambiguous))
    }
    func testNoTableMeansNoGate() {
        let c = cls([("ligustrum_sinense", 0.95), ("viburnum_dentatum", 0.02)])
        XCTAssertEqual(ScanDecision.decide(quality: .perfect, classification: c, catalog: catalog, thresholds: t, similarity: nil), .confirmedInvasive(species: "ligustrum_sinense", confidence: 0.95))
    }
    func testGateCanBeDisabledByThresholds() {
        var tt = t; tt.embeddingGateEnabled = false
        let c = cls([("ligustrum_sinense", 0.95), ("viburnum_dentatum", 0.02)])
        XCTAssertEqual(ScanDecision.decide(quality: .perfect, classification: c, catalog: catalog, thresholds: tt, similarity: { _ in (value: 0.1, floor: 0.6) }), .confirmedInvasive(species: "ligustrum_sinense", confidence: 0.95))
    }
    func testEvidenceAverageAndEntropy() {
        let a = [ClassProbability(label: "x", probability: 0.8), ClassProbability(label: "y", probability: 0.2)]
        let b = [ClassProbability(label: "x", probability: 0.4), ClassProbability(label: "y", probability: 0.6)]
        let avg = Evidence.average([a, b])
        XCTAssertEqual(avg.first?.label, "x"); XCTAssertEqual(avg.first!.probability, 0.6, accuracy: 1e-9)
        XCTAssertLessThan(Evidence.normalisedEntropy(a), Evidence.normalisedEntropy([ClassProbability(label: "x", probability: 0.5), ClassProbability(label: "y", probability: 0.5)]))
    }
}

final class FocusCropTests: XCTestCase {
    func testSmallSubjectGetsAPaddedSquareFocusRegionAndBigSubjectNone() {
        let small = QualityMetrics.SubjectBox(x: 0.6, y: 0.2, width: 0.2, height: 0.15)
        let r = try! XCTUnwrap(small.focusRegion())
        XCTAssertEqual(r.width, r.height, accuracy: 1e-6)
        XCTAssertGreaterThan(r.width, 0.2); XCTAssertLessThanOrEqual(r.maxX, 1); XCTAssertGreaterThanOrEqual(r.minY, 0)
        XCTAssertTrue(r.contains(CGPoint(x: 0.7, y: 0.275)), "region keeps the subject centre")
        XCTAssertNil(QualityMetrics.SubjectBox(x: 0.1, y: 0.1, width: 0.8, height: 0.8).focusRegion(), "a subject that fills the frame needs no focus crop")
        XCTAssertNil(QualityMetrics.SubjectBox(x: 0.5, y: 0.5, width: 0.05, height: 0.05).focusRegion(), "specks are ignored")
    }

    func testVariantsAddAFocusCropOnlyWhenGiven() {
        let ctx = CGContext(data: nil, width: 400, height: 300, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
        let img = ctx.makeImage()!
        XCTAssertEqual(TestTimeAugmentation.variants(of: img).count, 4)
        let v = TestTimeAugmentation.variants(of: img, focus: CGRect(x: 0.5, y: 0.5, width: 0.3, height: 0.3))
        XCTAssertEqual(v.count, 5)
        XCTAssertEqual(v.last!.width, 120, accuracy: 1); XCTAssertEqual(v.last!.height, 90, accuracy: 1)
    }
}

final class NativeMassTests: XCTestCase {
    private var catalog: SpeciesCatalog {
        var s = SpeciesCatalog.builtIn
        for l in ["quercus_alba", "quercus_nigra", "quercus_rubra"] {
            s.append(Species(label: l, scientificName: l, commonName: l, tier: .native, aggressiveness: 0, documentedAtPreserve: false, whyItMatters: "", howToRecognize: "", whatToPhotograph: "", lookAlike: nil, sourceURL: ""))
        }
        return SpeciesCatalog(species: s)
    }

    func testMassSplitBetweenSimilarNativesStillReadsAsNative() {
        let c = ClassificationResult(probabilities: [.init(label: "quercus_alba", probability: 0.38), .init(label: "quercus_nigra", probability: 0.27), .init(label: "quercus_rubra", probability: 0.12), .init(label: "ligustrum_sinense", probability: 0.08), .init(label: "other_plant", probability: 0.05)], modelVersion: "t")
        let out = ScanDecision.decideRaw(quality: .perfect, classification: c, catalog: catalog, thresholds: .defaults)
        guard case .looksNative(let label, let conf) = out else { return XCTFail("expected looksNative, got \(out)") }
        XCTAssertEqual(label, "quercus_alba"); XCTAssertEqual(conf, 0.82, accuracy: 1e-9)
    }

    func testPlausibleInvasiveStillWinsOverSplitNatives() {
        let c = ClassificationResult(probabilities: [.init(label: "ligustrum_sinense", probability: 0.56), .init(label: "quercus_alba", probability: 0.22), .init(label: "quercus_nigra", probability: 0.2)], modelVersion: "t")
        if case .looksNative = ScanDecision.decideRaw(quality: .perfect, classification: c, catalog: catalog, thresholds: .defaults) { XCTFail("an invasive at 0.56 must go to staff") }
        let d = ClassificationResult(probabilities: [.init(label: "quercus_alba", probability: 0.3), .init(label: "ligustrum_sinense", probability: 0.25), .init(label: "quercus_nigra", probability: 0.2)], modelVersion: "t")
        if case .looksNative = ScanDecision.decideRaw(quality: .perfect, classification: d, catalog: catalog, thresholds: .defaults) { XCTFail("benign mass 0.50 is below the 0.60 bar: this must stay ambiguous") }
    }
}

final class LockProbabilityTests: XCTestCase {
    func testNativeLockUsesCombinedMassButInvasiveLockUsesItsOwnProbability() {
        var s = SpeciesCatalog.builtIn
        for l in ["quercus_alba", "quercus_nigra"] {
            s.append(Species(label: l, scientificName: l, commonName: l, tier: .native, aggressiveness: 0, documentedAtPreserve: false, whyItMatters: "", howToRecognize: "", whatToPhotograph: "", lookAlike: nil, sourceURL: ""))
        }
        let catalog = SpeciesCatalog(species: s)
        let oaks = ClassificationResult(probabilities: [.init(label: "quercus_alba", probability: 0.4), .init(label: "quercus_nigra", probability: 0.3), .init(label: "ligustrum_sinense", probability: 0.2), .init(label: "not_plant", probability: 0.1)], modelVersion: "t")
        XCTAssertEqual(ScanDecision.lockProbability(oaks, catalog: catalog), 0.7, accuracy: 1e-9)
        XCTAssertEqual(ScanDecision.lockTarget(oaks, catalog: catalog).label, ScanDecision.nativeLockLabel)
        // sister natives alternating on top still lock, because they share one lock key
        var tracker = LockOnTracker(thresholds: .defaults)
        var state = LockOnTracker.State.idle
        for i in 0..<6 {
            let a = i % 2 == 0 ? 0.42 : 0.3, b = i % 2 == 0 ? 0.3 : 0.42
            let frame = ClassificationResult(probabilities: [.init(label: "quercus_alba", probability: a), .init(label: "quercus_nigra", probability: b), .init(label: "other_plant", probability: 0.1)], modelVersion: "t")
            state = tracker.push(ScanDecision.lockTarget(frame, catalog: catalog), distribution: frame.probabilities)
        }
        if case .locked(let label, let p) = state { XCTAssertEqual(label, ScanDecision.nativeLockLabel); XCTAssertEqual(p, 0.82, accuracy: 1e-6) } else { XCTFail("expected a lock, got \(state)") }
        let privet = ClassificationResult(probabilities: [.init(label: "ligustrum_sinense", probability: 0.5), .init(label: "quercus_alba", probability: 0.3), .init(label: "quercus_nigra", probability: 0.2)], modelVersion: "t")
        XCTAssertEqual(ScanDecision.lockProbability(privet, catalog: catalog), 0.5, accuracy: 1e-9)
        let notPlant = ClassificationResult(probabilities: [.init(label: "not_plant", probability: 0.45), .init(label: "quercus_alba", probability: 0.3), .init(label: "other_plant", probability: 0.25)], modelVersion: "t")
        XCTAssertEqual(ScanDecision.lockProbability(notPlant, catalog: catalog), 0.45, accuracy: 1e-9)
    }
}

/// The bundled thresholds.json must decode; otherwise Config.scan silently falls back to defaults and the
/// per-species confirm floors tuned on validation data are lost.
final class BundledThresholdsTests: XCTestCase {
    func testBundledThresholdsDecodeWithPerClassFloors() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "thresholds", withExtension: "json"))
        let t = try JSONDecoder().decode(ScanThresholds.self, from: Data(contentsOf: url))
        XCTAssertFalse(t.perClassConfirmMin.isEmpty)
        XCTAssertEqual(Config.scan, t, "Config.scan should be the bundled thresholds, not the defaults")
        XCTAssertGreaterThanOrEqual(t.confirmMinProbability, 0.75)
    }
}
