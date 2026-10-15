import Foundation
import SwiftData

/// One sighting. Photos live as JPEG files in Application Support (EXIF stripped); coordinates live here.
@Model
final class Report {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var latitude: Double
    var longitude: Double
    var horizontalAccuracy: Double
    var photoFileName: String
    var species: String            // classifier label or "unknown"
    var speciesName: String
    var confidence: Double
    var top3JSON: String           // [ClassProbability] encoded
    var modelVersion: String
    var qualityJSON: String        // QualityMetrics encoded
    var patchSizeRaw: String
    var note: String
    var statusRaw: String
    var statusUpdatedAt: Date
    var nearestTrailName: String
    var distanceToCreekMeters: Double?
    var priorityScore: Double
    var sentAt: Date?
    var isPractice: Bool
    var needsExpertReview: Bool
    var lowAccuracy: Bool
    var additionalSightings: Int   // "Add to existing report" taps
    var fieldTrueLabel: String?    // Field Test mode: label given by a person who knows the plant
    var fieldTrueLabelAt: Date?
    var remoteID: String?          // id on the preserve dashboard once sent
    var remoteStatus: String?
    var lastRemoteCheck: Date?

    init(id: UUID = UUID(), createdAt: Date = .now, latitude: Double, longitude: Double, horizontalAccuracy: Double,
         photoFileName: String, species: String, speciesName: String, confidence: Double, top3: [ClassProbability],
         modelVersion: String, quality: QualityMetrics, patchSize: PatchSize, note: String, status: ReportStatus = .new,
         nearestTrailName: String, distanceToCreekMeters: Double?, isPractice: Bool, needsExpertReview: Bool, lowAccuracy: Bool) {
        self.id = id
        self.createdAt = createdAt
        self.latitude = latitude
        self.longitude = longitude
        self.horizontalAccuracy = horizontalAccuracy
        self.photoFileName = photoFileName
        self.species = species
        self.speciesName = speciesName
        self.confidence = confidence
        self.top3JSON = (try? String(data: JSONEncoder().encode(top3), encoding: .utf8)) ?? "[]"
        self.modelVersion = modelVersion
        self.qualityJSON = (try? String(data: JSONEncoder().encode(quality), encoding: .utf8)) ?? "{}"
        self.patchSizeRaw = patchSize.rawValue
        self.note = note
        self.statusRaw = status.rawValue
        self.statusUpdatedAt = createdAt
        self.nearestTrailName = nearestTrailName
        self.distanceToCreekMeters = distanceToCreekMeters
        self.priorityScore = 0
        self.sentAt = nil
        self.isPractice = isPractice
        self.needsExpertReview = needsExpertReview
        self.lowAccuracy = lowAccuracy
        self.additionalSightings = 0
        self.fieldTrueLabel = nil
        self.fieldTrueLabelAt = nil
        self.remoteID = nil
        self.remoteStatus = nil
        self.lastRemoteCheck = nil
    }

    var status: ReportStatus {
        get { ReportStatus(rawValue: statusRaw) ?? .new }
        set { statusRaw = newValue.rawValue; statusUpdatedAt = .now }
    }
    var patchSize: PatchSize {
        get { PatchSize(rawValue: patchSizeRaw) ?? .patch }
        set { patchSizeRaw = newValue.rawValue }
    }
    var top3: [ClassProbability] { (try? JSONDecoder().decode([ClassProbability].self, from: Data(top3JSON.utf8))) ?? [] }
    var quality: QualityMetrics { (try? JSONDecoder().decode(QualityMetrics.self, from: Data(qualityJSON.utf8))) ?? QualityMetrics() }
    var location: GeoPoint { GeoPoint(latitude: latitude, longitude: longitude) }

    var row: ReportRow {
        ReportRow(id: id, createdAt: createdAt, latitude: latitude, longitude: longitude, horizontalAccuracy: horizontalAccuracy,
                  species: species, speciesName: speciesName, confidence: confidence, status: status, statusUpdatedAt: statusUpdatedAt,
                  patchSize: patchSize, note: note, needsExpertReview: needsExpertReview, isPractice: isPractice,
                  nearestTrailName: nearestTrailName, distanceToCreekMeters: distanceToCreekMeters, priorityScore: priorityScore,
                  modelVersion: modelVersion, sentAt: sentAt)
    }
}
