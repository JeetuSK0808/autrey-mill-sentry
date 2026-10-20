import XCTest
@testable import AutreyMillSentry

/// Exercises the real bundled Core ML model (two outputs: probabilities + embedding) on bundled reference photos.
final class CoreMLClassifierTests: XCTestCase {
    func loadImage(_ name: String) throws -> CGImage {
        let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "jpg"), "missing \(name).jpg")
        return try XCTUnwrap(ImageLoading.cgImage(fromJPEGData: Data(contentsOf: url), maxDimension: 1200))
    }

    func testModelLoadsWithLabelsAndEmbeddingTable() throws {
        let clf = try XCTUnwrap(CoreMLClassifier(), "InvasiveClassifier.mlmodelc should be bundled and loadable")
        XCTAssertFalse(clf.isMock)
        let table = EmbeddingTable()
        XCTAssertTrue(table.isAvailable)
        XCTAssertEqual(table.dimension, 1280)
        XCTAssertNotNil(table.entries["ligustrum_sinense"])
    }

    func testPrivetReferencePhotoIsRecognisedWithEmbedding() throws {
        let clf = try XCTUnwrap(CoreMLClassifier())
        let img = try loadImage("learn_ligustrum_sinense")
        let r = try clf.classify(img, orientation: .up)
        XCTAssertGreaterThan(r.probabilities.count, 100, "one probability per class")
        XCTAssertEqual(r.top?.label, "ligustrum_sinense")
        XCTAssertGreaterThan(r.top?.probability ?? 0, 0.5)
        let sum = r.probabilities.map(\.probability).reduce(0, +)
        XCTAssertEqual(sum, 1.0, accuracy: 0.02, "calibrated softmax")
        let emb = try XCTUnwrap(r.embedding)
        XCTAssertEqual(emb.count, 1280)
        let norm = sqrt(emb.map { $0 * $0 }.reduce(0, +))
        XCTAssertEqual(Double(norm), 1.0, accuracy: 0.05, "L2-normalised embedding")
        let table = EmbeddingTable()
        let sim = try XCTUnwrap(table.similarity(of: emb, to: "ligustrum_sinense"))
        XCTAssertGreaterThan(sim.value, sim.floor, "the reference photo should sit inside its own class radius")
    }

    func testDecisionOnReferencePhotoUsesRealThresholds() throws {
        let clf = try XCTUnwrap(CoreMLClassifier())
        let catalog = SpeciesCatalog(species: SpeciesCatalog.builtIn)
        let img = try loadImage("learn_hedera_helix")
        let r = try clf.classify(img, orientation: .up)
        let table = EmbeddingTable()
        let outcome = ScanDecision.decide(quality: .perfect, classification: r, catalog: catalog, similarity: { label in r.embedding.flatMap { table.similarity(of: $0, to: label) } })
        switch outcome {
        case .confirmedInvasive(let s, _): XCTAssertEqual(s, "hedera_helix")
        case .possibleInvasive(let c): XCTAssertEqual(c.first?.label, "hedera_helix")
        default: XCTFail("English ivy reference photo should be called invasive, got \(outcome)")
        }
    }

    func testDrawnSampleLeafIsNotConfirmedInvasive() throws {
        let clf = try XCTUnwrap(CoreMLClassifier())
        let catalog = SpeciesCatalog(species: SpeciesCatalog.builtIn)
        let img = try loadImage("sample_leaf")
        let r = try clf.classify(img, orientation: .up)
        let table = EmbeddingTable()
        let outcome = ScanDecision.decide(quality: .perfect, classification: r, catalog: catalog, similarity: { label in r.embedding.flatMap { table.similarity(of: $0, to: label) } })
        if case .confirmedInvasive = outcome { XCTFail("a cartoon leaf must never be a confirmed invasive: \(outcome)") }
    }
}

final class EnsembleClassifierTests: XCTestCase {
    func testEnsembleAveragesAndKeepsPrimaryEmbedding() throws {
        let primary = try XCTUnwrap(CoreMLClassifier())
        guard let secondary = CoreMLClassifier(resourceName: "InvasiveClassifierB") else { throw XCTSkip("no second model bundled in this build (single-model interim)") }
        let ens = EnsembleClassifier(primary: primary, secondary: secondary)
        let url = try XCTUnwrap(Bundle.main.url(forResource: "learn_ligustrum_sinense", withExtension: "jpg"))
        let img = try XCTUnwrap(ImageLoading.cgImage(fromJPEGData: Data(contentsOf: url), maxDimension: 1200))
        let r = try ens.classify(img, orientation: .up)
        XCTAssertEqual(r.top?.label, "ligustrum_sinense")
        XCTAssertEqual(r.probabilities.map(\.probability).reduce(0, +), 1.0, accuracy: 0.03)
        XCTAssertEqual(r.embedding?.count, 1280)
        XCTAssertTrue(r.modelVersion.contains("+"))
        XCTAssertTrue(ClassifierFactory.make(catalog: SpeciesCatalog(species: SpeciesCatalog.builtIn)) is EnsembleClassifier)
    }
}

/// Every label the bundled model can output must be a species the app knows (name, tier, Learn page), or one of the
/// two catch-all labels. Otherwise a scan could show a raw label like "liquidambar_styraciflua".
final class LabelCoverageTests: XCTestCase {
    @MainActor func testEveryModelLabelIsInTheCatalog() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "labels", withExtension: "json"))
        let obj = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let labels = try XCTUnwrap(obj["labels"] as? [String])
        let app = AppModel()
        let missing = labels.filter { app.catalog.species(for: $0) == nil && $0 != "other_plant" && $0 != "not_plant" }
        XCTAssertTrue(missing.isEmpty, "labels without catalog entries: \(missing)")
        XCTAssertGreaterThan(app.catalog.natives.count, 14, "local native species should be loaded from local_species.json")
    }
}

/// Common natives must come back as "looks native", not as an invasive guess. Active once the bundled model knows
/// them (v4 and later); skipped with older models.
final class LocalNativeRecognitionTests: XCTestCase {
    @MainActor func testSweetgumAndChristmasFernReferencePhotosReadAsNative() throws {
        let app = AppModel()
        let url = try XCTUnwrap(Bundle.main.url(forResource: "labels", withExtension: "json"))
        let labels = try XCTUnwrap((JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])?["labels"] as? [String])
        try XCTSkipUnless(labels.contains("liquidambar_styraciflua"), "bundled model predates the local native classes")
        let clf = try XCTUnwrap(CoreMLClassifier())
        for label in ["liquidambar_styraciflua", "polystichum_acrostichoides"] {
            let imgURL = try XCTUnwrap(Bundle.main.url(forResource: "learn_\(label)", withExtension: "jpg"))
            let img = try XCTUnwrap(ImageLoading.cgImage(fromJPEGData: Data(contentsOf: imgURL), maxDimension: 1200))
            let r = try clf.classify(img, orientation: .up)
            let outcome = ScanDecision.decideRaw(quality: .perfect, classification: r, catalog: app.catalog)
            if case .looksNative = outcome {} else { XCTFail("\(label): expected looksNative, got \(outcome); top \(r.top3.map { "\($0.label) \(Int($0.probability * 100))" })") }
        }
    }
}
