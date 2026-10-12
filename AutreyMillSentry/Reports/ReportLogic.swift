import Foundation

/// Duplicate detection: same species within `radiusMeters` in the last `windowDays`.
enum DuplicateFinder {
    struct Candidate: Sendable, Equatable { var id: UUID; var species: String; var location: GeoPoint; var createdAt: Date }

    static func existingReport(species: String, location: GeoPoint, now: Date, candidates: [Candidate],
                               radiusMeters: Double = Config.duplicateRadiusMeters,
                               windowDays: Int = Config.duplicateWindowDays) -> Candidate? {
        let cutoff = now.addingTimeInterval(-Double(windowDays) * 86_400)
        return candidates
            .filter { $0.species == species && $0.createdAt >= cutoff && Geo.distanceMeters($0.location, location) <= radiusMeters }
            .min { Geo.distanceMeters($0.location, location) < Geo.distanceMeters($1.location, location) }
    }
}

/// CSV export with the optional ~100 m rounding for anything meant to be public.
enum ReportCSV {
    static let header = "id,created_at,latitude,longitude,horizontal_accuracy_m,species_label,species_name,confidence,status,status_updated_at,patch_size,needs_expert_review,is_practice,nearest_trail,distance_to_creek_m,priority_score,model_version,note"

    static func make(_ rows: [ReportRow], roundCoordinates: Bool, decimals: Int = Config.exportRoundingDecimals) -> String {
        let iso = ISO8601DateFormatter()
        var lines = [header]
        for r in rows {
            let lat = roundCoordinates ? round(r.latitude, decimals) : r.latitude
            let lon = roundCoordinates ? round(r.longitude, decimals) : r.longitude
            let fields: [String] = [
                r.id.uuidString, iso.string(from: r.createdAt), fmt(lat, 6), fmt(lon, 6), fmt(r.horizontalAccuracy, 1),
                r.species, r.speciesName, fmt(r.confidence, 3), r.status.rawValue, iso.string(from: r.statusUpdatedAt),
                r.patchSize.rawValue, r.needsExpertReview ? "true" : "false", r.isPractice ? "true" : "false",
                r.nearestTrailName, r.distanceToCreekMeters.map { fmt($0, 1) } ?? "", fmt(r.priorityScore, 1), r.modelVersion, r.note,
            ]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func round(_ v: Double, _ decimals: Int) -> Double {
        let p = pow(10.0, Double(decimals))
        return (v * p).rounded() / p
    }
    static func fmt(_ v: Double, _ decimals: Int) -> String { String(format: "%.\(decimals)f", v) }
    static func escape(_ s: String) -> String {
        if s.contains(",") || s.contains("\"") || s.contains("\n") { return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
        return s
    }
}
