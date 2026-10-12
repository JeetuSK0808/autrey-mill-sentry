import Foundation
import MapKit

/// Bundled OpenStreetMap geometry for the preserve. Loaded once; works offline.
struct Trail: Identifiable, Hashable {
    let id: String
    let name: String
    let coordinates: [CLLocationCoordinate2D]
    static func == (a: Trail, b: Trail) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }
    var points: [GeoPoint] { coordinates.map { GeoPoint(latitude: $0.latitude, longitude: $0.longitude) } }
}

struct Waterway: Identifiable {
    let id: String
    let name: String
    let isPolygon: Bool
    let coordinates: [CLLocationCoordinate2D]
    var points: [GeoPoint] { coordinates.map { GeoPoint(latitude: $0.latitude, longitude: $0.longitude) } }
}

struct PointOfInterest: Identifiable {
    let id: String
    let kind: String
    let name: String
    let coordinate: CLLocationCoordinate2D
    var symbolName: String {
        switch kind {
        case "parking": return "parkingsign"
        case "toilets": return "toilet"
        case "bench": return "chair"
        case "gate": return "door.left.hand.closed"
        case "viewpoint": return "binoculars"
        case "building": return "building.columns"
        default: return "mappin"
        }
    }
    var isShown: Bool { kind != "mast" }
}

final class PreserveData {
    static let shared = PreserveData()

    private(set) var trails: [Trail] = []
    private(set) var boundary: [GeoPoint] = []
    private(set) var boundaryCoordinates: [CLLocationCoordinate2D] = []
    private(set) var waterways: [Waterway] = []
    private(set) var pois: [PointOfInterest] = []
    private(set) var loadError: String?

    init(bundle: Bundle = .main) { load(bundle: bundle) }

    private func load(bundle: Bundle) {
        trails = features("trails", bundle: bundle).compactMap { f -> Trail? in
            guard let line = f.geometry.first as? MKPolyline else { return nil }
            let props = f.props
            let name = props["display_name"] as? String ?? props["name"] as? String ?? "Unnamed trail"
            return Trail(id: "\(props["osm_id"] ?? UUID().uuidString)", name: name, coordinates: line.coords)
        }
        if let b = features("boundary", bundle: bundle).first, let poly = b.geometry.first as? MKPolygon {
            boundaryCoordinates = poly.coords
            boundary = boundaryCoordinates.map { GeoPoint(latitude: $0.latitude, longitude: $0.longitude) }
        }
        waterways = features("waterways", bundle: bundle).compactMap { f -> Waterway? in
            let name = f.props["display_name"] as? String ?? "Stream"
            if let line = f.geometry.first as? MKPolyline { return Waterway(id: "\(f.props["osm_id"] ?? "")", name: name, isPolygon: false, coordinates: line.coords) }
            if let poly = f.geometry.first as? MKPolygon { return Waterway(id: "\(f.props["osm_id"] ?? "")", name: name, isPolygon: true, coordinates: poly.coords) }
            return nil
        }
        pois = features("poi", bundle: bundle).compactMap { f -> PointOfInterest? in
            let kind = f.props["kind"] as? String ?? "poi"
            let name = f.props["name"] as? String ?? kind.capitalized
            if let pt = f.geometry.first as? MKPointAnnotation {
                return PointOfInterest(id: "\(f.props["osm_id"] ?? "")", kind: kind, name: name, coordinate: pt.coordinate)
            }
            if let poly = f.geometry.first as? MKPolygon, f.props["name"] != nil {
                return PointOfInterest(id: "\(f.props["osm_id"] ?? "")", kind: kind, name: name, coordinate: poly.coordinate)
            }
            return nil
        }
    }

    private struct Feature { let geometry: [MKShape & MKGeoJSONObject]; let props: [String: Any] }

    private func features(_ name: String, bundle: Bundle) -> [Feature] {
        guard let url = bundle.url(forResource: name, withExtension: "geojson"), let data = try? Data(contentsOf: url) else {
            loadError = "Missing \(name).geojson"; return []
        }
        guard let objects = try? MKGeoJSONDecoder().decode(data) else { loadError = "Bad \(name).geojson"; return [] }
        return objects.compactMap { obj -> Feature? in
            guard let f = obj as? MKGeoJSONFeature else { return nil }
            let props = (f.properties.flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any]) ?? [:]
            return Feature(geometry: f.geometry, props: props)
        }
    }

    // MARK: Queries

    func isInsidePreserve(_ p: GeoPoint, bufferMeters: Double = Config.geofenceBufferMeters) -> Bool {
        guard !boundary.isEmpty else { return true }  // no data: do not block the user
        return Geo.isInside(boundary, point: p, bufferMeters: bufferMeters)
    }

    func distanceToPreserveEdge(_ p: GeoPoint) -> Double {
        guard !boundary.isEmpty else { return 0 }
        return Geo.contains(boundary, point: p) ? 0 : Geo.distanceMeters(from: p, toPolygonEdge: boundary)
    }

    func nearestTrail(to p: GeoPoint) -> (name: String, distance: Double)? {
        var best: (String, Double)?
        for t in trails {
            let d = Geo.distanceMeters(from: p, toPolyline: t.points)
            if best == nil || d < best!.1 { best = (t.name, d) }
        }
        return best
    }

    func distanceToCreek(from p: GeoPoint) -> Double? {
        var best: Double?
        for w in waterways {
            let d = w.isPolygon ? Geo.distanceMeters(from: p, toPolygonEdge: w.points) : Geo.distanceMeters(from: p, toPolyline: w.points)
            if best == nil || d < best! { best = d }
        }
        return best
    }
}

extension MKMultiPoint {
    var coords: [CLLocationCoordinate2D] {
        var c = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&c, range: NSRange(location: 0, length: pointCount))
        return c
    }
}
