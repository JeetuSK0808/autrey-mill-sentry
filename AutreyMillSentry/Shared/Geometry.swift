import Foundation

/// A plain latitude/longitude pair so geometry can be unit tested without MapKit.
struct GeoPoint: Hashable, Codable, Sendable {
    var latitude: Double
    var longitude: Double
}

enum Geo {
    static let earthRadiusMeters = 6_371_008.8

    /// Great-circle distance in metres (haversine).
    static func distanceMeters(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        let dLat = (b.latitude - a.latitude) * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let la1 = a.latitude * .pi / 180, la2 = b.latitude * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(la1) * cos(la2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadiusMeters * asin(min(1, sqrt(h)))
    }

    /// Local equirectangular projection to metres around `origin` (accurate within a few km).
    static func project(_ p: GeoPoint, origin: GeoPoint) -> (x: Double, y: Double) {
        let kx = cos(origin.latitude * .pi / 180) * .pi / 180 * earthRadiusMeters
        let ky = .pi / 180 * earthRadiusMeters
        return ((p.longitude - origin.longitude) * kx, (p.latitude - origin.latitude) * ky)
    }

    /// Ray-casting point-in-polygon. The polygon may be open or closed.
    static func contains(_ polygon: [GeoPoint], point: GeoPoint) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let pi = polygon[i], pj = polygon[j]
            if (pi.latitude > point.latitude) != (pj.latitude > point.latitude) {
                let x = (pj.longitude - pi.longitude) * (point.latitude - pi.latitude) / (pj.latitude - pi.latitude) + pi.longitude
                if point.longitude < x { inside.toggle() }
            }
            j = i
        }
        return inside
    }

    private static func segmentDistance(px: Double, py: Double, ax: Double, ay: Double, bx: Double, by: Double) -> Double {
        let dx = bx - ax, dy = by - ay
        if dx == 0 && dy == 0 { return hypot(px - ax, py - ay) }
        let t = max(0, min(1, ((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy)))
        return hypot(px - (ax + t * dx), py - (ay + t * dy))
    }

    /// Shortest distance in metres from a point to a polyline.
    static func distanceMeters(from point: GeoPoint, toPolyline line: [GeoPoint]) -> Double {
        guard let first = line.first else { return .infinity }
        if line.count == 1 { return distanceMeters(point, first) }
        let p = project(point, origin: point)
        var best = Double.infinity
        for i in 0..<(line.count - 1) {
            let a = project(line[i], origin: point), b = project(line[i + 1], origin: point)
            best = min(best, segmentDistance(px: p.x, py: p.y, ax: a.x, ay: a.y, bx: b.x, by: b.y))
        }
        return best
    }

    /// Distance to the edge of a polygon (0 if the point is inside).
    static func distanceMeters(from point: GeoPoint, toPolygonEdge polygon: [GeoPoint]) -> Double {
        guard polygon.count >= 2 else { return .infinity }
        var closed = polygon
        if closed.first != closed.last, let f = closed.first { closed.append(f) }
        return distanceMeters(from: point, toPolyline: closed)
    }

    /// Inside the polygon, or within `bufferMeters` of its edge.
    static func isInside(_ polygon: [GeoPoint], point: GeoPoint, bufferMeters: Double) -> Bool {
        if contains(polygon, point: point) { return true }
        return distanceMeters(from: point, toPolygonEdge: polygon) <= bufferMeters
    }

    /// US units for everything the user reads: feet under a tenth of a mile, miles above.
    static func roundedDistanceDescription(_ meters: Double) -> String {
        let feet = meters * 3.28084
        if feet < 528 { return "\(Int(feet.rounded())) ft" }
        let miles = meters / 1609.344
        return miles < 10 ? String(format: "%.1f mi", miles) : "\(Int(miles.rounded())) mi"
    }
    static func feetDescription(_ meters: Double) -> String { "\(Int((meters * 3.28084).rounded())) ft" }
}
