import Foundation
import CoreLocation
import Observation

/// When In Use only. Never background. Starts on demand (scan screen, map) and stops when not needed.
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var authorization: CLAuthorizationStatus
    private(set) var latest: CLLocation?
    private(set) var lastError: String?
    var simulated: GeoPoint?   // DEBUG: set to pretend the phone is at the preserve

    override init() {
        authorization = .notDetermined   // the delegate callback below delivers the real value right after init
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 2
    }

    var isAuthorized: Bool {
        #if os(iOS)
        return authorization == .authorizedWhenInUse || authorization == .authorizedAlways
        #else
        return authorization == .authorizedAlways
        #endif
    }
    var isDenied: Bool { authorization == .denied || authorization == .restricted }

    func requestWhenInUse() {
        if authorization == .notDetermined { manager.requestWhenInUseAuthorization() }
    }

    func start() { if isAuthorized { manager.startUpdatingLocation() } }
    func stop() { manager.stopUpdatingLocation() }

    /// Best current fix, or the simulated one in debug.
    var current: (point: GeoPoint, accuracy: Double)? {
        if let s = simulated { return (s, 5) }
        guard let l = latest, l.horizontalAccuracy >= 0 else { return nil }
        return (GeoPoint(latitude: l.coordinate.latitude, longitude: l.coordinate.longitude), l.horizontalAccuracy)
    }

    /// Waits up to `timeout` seconds for a fix at least as good as `maxAccuracy` metres. Returns the best seen.
    func waitForFix(maxAccuracy: Double = Config.goodAccuracyMeters, timeout: TimeInterval = Config.locationWaitSeconds) async -> (point: GeoPoint, accuracy: Double)? {
        if let s = simulated { return (s, 5) }
        start()
        let deadline = Date().addingTimeInterval(timeout)
        var best = current
        while Date() < deadline {
            if let c = current {
                if best == nil || c.accuracy < best!.accuracy { best = c }
                if c.accuracy <= maxAccuracy { return c }
            }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return best
    }

    // MARK: CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorization = manager.authorizationStatus
        if isAuthorized { manager.startUpdatingLocation() }
    }
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let l = locations.last { latest = l }
    }
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        lastError = error.localizedDescription
    }
}
