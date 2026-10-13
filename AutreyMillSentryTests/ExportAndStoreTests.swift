import XCTest
import SwiftData
import UIKit
@testable import AutreyMillSentry

/// End-to-end store and export checks on an in-memory SwiftData container (runs inside the app host).
@MainActor
final class ExportAndStoreTests: XCTestCase {
    private func makeImage() -> CGImage {
        let r = UIGraphicsImageRenderer(size: CGSize(width: 400, height: 300))
        let img = r.image { ctx in
            UIColor.brown.setFill(); ctx.fill(CGRect(x: 0, y: 0, width: 400, height: 300))
            UIColor.green.setFill(); ctx.cgContext.fillEllipse(in: CGRect(x: 80, y: 40, width: 240, height: 220))
        }
        return img.cgImage!
    }

    func testCreatePackageWorkOrderAndLifecycle() async throws {
        let container = try ModelContainer(for: Report.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let ctx = container.mainContext
        let catalog = SpeciesCatalog(species: SpeciesCatalog.builtIn)
        let preserve = PreserveData(bundle: .main)
        let classification = ClassificationResult(probabilities: [ClassProbability(label: "ligustrum_sinense", probability: 0.9), ClassProbability(label: "viburnum_dentatum", probability: 0.05)], modelVersion: "test")
        let result = ScanResult(outcome: .confirmedInvasive(species: "ligustrum_sinense", confidence: 0.9), image: makeImage(), quality: .perfect,
                                classification: classification, location: Config.preserveCenter, horizontalAccuracy: 5, lowAccuracy: false,
                                isInsidePreserve: true, nearestTrailName: "Warsaw Trail", distanceToCreekMeters: 20, source: .picker)
        let r = try ReportStore.create(from: result, species: "ligustrum_sinense", speciesName: "Chinese privet", confidence: 0.9, needsExpertReview: false,
                                       patchSize: .few, note: "by the \"old\" bridge, left", fieldTrueLabel: nil, catalog: catalog, preserve: preserve, context: ctx)
        XCTAssertEqual(ReportStore.all(ctx).count, 1)
        XCTAssertGreaterThan(r.priorityScore, 60, "a fresh, confident, isolated privet near the creek should rank high")
        XCTAssertFalse(r.isPractice)
        XCTAssertNotNil(PhotoStore.load(r.photoFileName), "photo written to Application Support")

        // Stored photo carries no EXIF/GPS metadata
        let props = CGImageSourceCopyPropertiesAtIndex(CGImageSourceCreateWithURL(PhotoStore.url(for: r.photoFileName) as CFURL, nil)!, 0, nil) as? [CFString: Any]
        XCTAssertNil(props?[kCGImagePropertyGPSDictionary])
        let exif = props?[kCGImagePropertyExifDictionary] as? [CFString: Any]
        XCTAssertNil(exif?[kCGImagePropertyExifDateTimeOriginal])

        // Report package: PDF + CSV + photo
        let items = try LocalOnlySync().package([r], roundCoordinates: true)
        XCTAssertEqual(items.count, 3)
        let pdf = try XCTUnwrap(items.first { $0.pathExtension == "pdf" })
        let csv = try XCTUnwrap(items.first { $0.pathExtension == "csv" })
        XCTAssertGreaterThan(try Data(contentsOf: pdf).count, 2000)
        let csvText = try String(contentsOf: csv, encoding: .utf8)
        XCTAssertTrue(csvText.contains("ligustrum_sinense"))
        XCTAssertTrue(csvText.contains("34.020000,-84.233000"), "rounded coordinates in the public export")

        // Work order PDF (no map snapshots in tests)
        let wo = try WorkOrderPDF.make(reports: [r], snapshots: [:], context: ctx, catalog: catalog)
        XCTAssertGreaterThan(try Data(contentsOf: wo).count, 2000)

        // Field test CSV
        ReportStore.setFieldLabel("ligustrum_sinense", on: r, context: ctx)
        let dir = try ReportExport.exportDirectory()
        let field = try ReportExport.fieldTestCSV([r], to: dir)
        XCTAssertTrue(try String(contentsOf: field, encoding: .utf8).contains("ligustrum_sinense,0.900,false,ligustrum_sinense"))

        // Duplicate sighting and status lifecycle
        ReportStore.addSighting(to: r, note: "again", context: ctx)
        XCTAssertEqual(r.additionalSightings, 1)
        XCTAssertTrue(r.note.contains("again"))
        await ReportStore.update(status: .confirmed, of: r, context: ctx, catalog: catalog)
        XCTAssertEqual(r.status, .confirmed)
        await ReportStore.update(status: .dismissed, of: r, context: ctx, catalog: catalog)
        XCTAssertEqual(r.priorityScore, 0, "closed reports leave the ranking")

        // Practice report outside the preserve is never ranked
        var outside = result; outside.location = GeoPoint(latitude: 34.0754, longitude: -84.2941); outside.isInsidePreserve = false
        let p = try ReportStore.create(from: outside, species: "hedera_helix", speciesName: "English ivy", confidence: 0.95, needsExpertReview: false,
                                       patchSize: .few, note: "", fieldTrueLabel: nil, catalog: catalog, preserve: preserve, context: ctx)
        XCTAssertTrue(p.isPractice)
        XCTAssertEqual(p.priorityScore, 0)

        ReportStore.deleteAll(context: ctx)
        XCTAssertEqual(ReportStore.all(ctx).count, 0)
        XCTAssertNil(PhotoStore.load(r.photoFileName))
    }
}
