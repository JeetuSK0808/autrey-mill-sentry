import Foundation

enum ReportStatus: String, Codable, CaseIterable, Sendable, Identifiable {
    case new, confirmed, treated, dismissed
    var id: String { rawValue }
    var title: String {
        switch self {
        case .new: return "New"
        case .confirmed: return "Confirmed"
        case .treated: return "Treated"
        case .dismissed: return "Dismissed"
        }
    }
    /// Shape names are part of the status signal so colour is never the only cue.
    var symbolName: String {
        switch self {
        case .new: return "circle.fill"
        case .confirmed: return "diamond.fill"
        case .treated: return "checkmark.seal.fill"
        case .dismissed: return "xmark.octagon.fill"
        }
    }
    var isOpen: Bool { self == .new || self == .confirmed }
}

enum PatchSize: String, Codable, CaseIterable, Sendable, Identifiable {
    case few, patch, large
    var id: String { rawValue }
    var title: String {
        switch self {
        case .few: return "Few plants"
        case .patch: return "Patch"
        case .large: return "Large stand"
        }
    }
    var detail: String {
        switch self {
        case .few: return "1 to a handful of plants"
        case .patch: return "A patch you could walk around"
        case .large: return "Bigger than a room"
        }
    }
}

/// Plain value used by exports, ranking and tests so they do not depend on SwiftData.
struct ReportRow: Codable, Sendable, Identifiable, Hashable {
    var id: UUID
    var createdAt: Date
    var latitude: Double
    var longitude: Double
    var horizontalAccuracy: Double
    var species: String            // classifier label, "unknown" for Tier 3
    var speciesName: String
    var confidence: Double
    var status: ReportStatus
    var statusUpdatedAt: Date
    var patchSize: PatchSize
    var note: String
    var needsExpertReview: Bool
    var isPractice: Bool
    var nearestTrailName: String
    var distanceToCreekMeters: Double?
    var priorityScore: Double
    var modelVersion: String
    var sentAt: Date?

    var location: GeoPoint { GeoPoint(latitude: latitude, longitude: longitude) }
}
