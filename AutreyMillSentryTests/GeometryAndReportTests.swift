import XCTest
@testable import AutreyMillSentry

final class GeometryTests: XCTestCase {
    let square = [GeoPoint(latitude: 34.0, longitude: -84.0), GeoPoint(latitude: 34.0, longitude: -84.01), GeoPoint(latitude: 34.01, longitude: -84.01), GeoPoint(latitude: 34.01, longitude: -84.0)]

    func testHaversineKnownDistance() {
        // About 111 km per degree of latitude
        let d = Geo.distanceMeters(GeoPoint(latitude: 34, longitude: -84), GeoPoint(latitude: 35, longitude: -84))
        XCTAssertEqual(d, 111_195, accuracy: 300)
    }
    func testPointInPolygon() {
        XCTAssertTrue(Geo.contains(square, point: GeoPoint(latitude: 34.005, longitude: -84.005)))
        XCTAssertFalse(Geo.contains(square, point: GeoPoint(latitude: 34.02, longitude: -84.005)))
    }
    func testBufferExtendsInside() {
        let justOutside = GeoPoint(latitude: 34.0102, longitude: -84.005)   // ~22 m north of the edge
        XCTAssertFalse(Geo.contains(square, point: justOutside))
        XCTAssertTrue(Geo.isInside(square, point: justOutside, bufferMeters: 60))
        XCTAssertFalse(Geo.isInside(square, point: justOutside, bufferMeters: 5))
    }
    func testDistanceToPolyline() {
        let line = [GeoPoint(latitude: 34.0, longitude: -84.0), GeoPoint(latitude: 34.0, longitude: -84.01)]
        let d = Geo.distanceMeters(from: GeoPoint(latitude: 34.001, longitude: -84.005), toPolyline: line)
        XCTAssertEqual(d, 111, accuracy: 3)
    }

    // Real bundled data
    func testPreserveBoundaryContainsCenter() {
        let p = PreserveData(bundle: .main)
        XCTAssertFalse(p.boundary.isEmpty, p.loadError ?? "")
        XCTAssertTrue(p.isInsidePreserve(Config.preserveCenter))
        XCTAssertFalse(p.isInsidePreserve(GeoPoint(latitude: 34.0754, longitude: -84.2941)))   // downtown Alpharetta
        XCTAssertFalse(p.trails.isEmpty)
        XCTAssertNotNil(p.nearestTrail(to: Config.preserveCenter))
        XCTAssertNotNil(p.distanceToCreek(from: Config.preserveCenter))
        XCTAssertTrue(p.trails.contains { $0.name == "Warsaw Trail" })
        XCTAssertTrue(p.waterways.contains { $0.name == "Sal's Creek" })
    }
}

final class DuplicateFinderTests: XCTestCase {
    let here = GeoPoint(latitude: 34.0200, longitude: -84.2326)
    func cand(_ species: String, metersEast: Double, daysAgo: Double) -> DuplicateFinder.Candidate {
        let lon = here.longitude + metersEast / (111_320 * cos(here.latitude * .pi / 180))
        return DuplicateFinder.Candidate(id: UUID(), species: species, location: GeoPoint(latitude: here.latitude, longitude: lon), createdAt: Date().addingTimeInterval(-daysAgo * 86_400))
    }
    func testFindsNearbyRecentSameSpecies() {
        let c = cand("hedera_helix", metersEast: 5, daysAgo: 1)
        XCTAssertEqual(DuplicateFinder.existingReport(species: "hedera_helix", location: here, now: .now, candidates: [c])?.id, c.id)
    }
    func testIgnoresFar() { XCTAssertNil(DuplicateFinder.existingReport(species: "hedera_helix", location: here, now: .now, candidates: [cand("hedera_helix", metersEast: 40, daysAgo: 1)])) }
    func testIgnoresOld() { XCTAssertNil(DuplicateFinder.existingReport(species: "hedera_helix", location: here, now: .now, candidates: [cand("hedera_helix", metersEast: 2, daysAgo: 9)])) }
    func testIgnoresOtherSpecies() { XCTAssertNil(DuplicateFinder.existingReport(species: "hedera_helix", location: here, now: .now, candidates: [cand("vinca_minor", metersEast: 2, daysAgo: 1)])) }
    func testPicksClosest() {
        let a = cand("hedera_helix", metersEast: 8, daysAgo: 1), b = cand("hedera_helix", metersEast: 2, daysAgo: 2)
        XCTAssertEqual(DuplicateFinder.existingReport(species: "hedera_helix", location: here, now: .now, candidates: [a, b])?.id, b.id)
    }
}

final class ReportCSVTests: XCTestCase {
    func row(note: String = "") -> ReportRow {
        ReportRow(id: UUID(), createdAt: Date(timeIntervalSince1970: 1_700_000_000), latitude: 34.0201234, longitude: -84.2326789, horizontalAccuracy: 8.4,
                  species: "hedera_helix", speciesName: "English ivy", confidence: 0.912, status: .new, statusUpdatedAt: Date(timeIntervalSince1970: 1_700_000_000),
                  patchSize: .patch, note: note, needsExpertReview: false, isPractice: false, nearestTrailName: "Warsaw Trail", distanceToCreekMeters: 12.3,
                  priorityScore: 77.5, modelVersion: "test", sentAt: nil)
    }
    func testHeaderAndRow() {
        let csv = ReportCSV.make([row()], roundCoordinates: false)
        let lines = csv.split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].hasPrefix("id,created_at,latitude,longitude"))
        XCTAssertTrue(lines[1].contains("34.020123,-84.232679"))
        XCTAssertTrue(lines[1].contains("Warsaw Trail"))
    }
    func testRoundingToAbout100m() {
        let csv = ReportCSV.make([row()], roundCoordinates: true)
        XCTAssertTrue(csv.contains("34.020000,-84.233000"), csv)
    }
    func testEscapesCommasAndQuotes() {
        let csv = ReportCSV.make([row(note: "near the \"old\" bridge, left side")], roundCoordinates: false)
        XCTAssertTrue(csv.contains("\"near the \"\"old\"\" bridge, left side\""))
    }
}

final class SpeciesCatalogTests: XCTestCase {
    func testBuiltInHasFourteenTier1AndLookAlikes() {
        let c = SpeciesCatalog(species: SpeciesCatalog.builtIn)
        XCTAssertEqual(c.tier1.count, 14)
        XCTAssertEqual(c.natives.count, 14)
        for s in c.tier1 { XCTAssertFalse(s.howToRecognize.isEmpty, s.label); XCTAssertFalse(s.sourceURL.isEmpty) }
        XCTAssertEqual(c.tier(of: "nope"), .other)
        XCTAssertEqual(c.name(for: "other_plant"), "Other plant")
        let labels = SpeciesCatalog.builtIn.map(\.label)
        XCTAssertEqual(Set(labels).count, labels.count, "duplicate labels")
    }
    func testTier2JSONLoads() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "tier2_species", withExtension: "json"))
        let t2 = try JSONDecoder().decode([Species].self, from: Data(contentsOf: url))
        XCTAssertGreaterThan(t2.count, 10)
        XCTAssertTrue(t2.allSatisfy { $0.tier == .tier2 })
    }
}
