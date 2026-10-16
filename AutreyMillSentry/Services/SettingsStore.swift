import Foundation
import Observation
import SwiftUI

/// UserDefaults-backed settings. No analytics, no identifiers, nothing leaves the device.
@Observable
final class SettingsStore {
    private let defaults: UserDefaults
    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        onboardingComplete = defaults.bool(forKey: "onboardingComplete")
        rangerMode = defaults.bool(forKey: "rangerMode")
        fieldTestMode = defaults.bool(forKey: "fieldTestMode")
        autoCapture = defaults.bool(forKey: "autoCapture")
        roundCoordinatesOnExport = defaults.bool(forKey: "roundCoordinatesOnExport")
        simulateLocation = defaults.bool(forKey: "simulateLocation")
        hapticsEnabled = defaults.object(forKey: "hapticsEnabled") as? Bool ?? true
        appearance = defaults.string(forKey: "appearance") ?? "system"
        scanDiagnostics = defaults.bool(forKey: "scanDiagnostics")
        dashboardURL = { let v = defaults.string(forKey: "dashboardURL") ?? ""; return v.isEmpty ? Config.defaultDashboardURL : v }()
    }
    var dashboardURL: String { didSet { defaults.set(dashboardURL, forKey: "dashboardURL") } }
    var dashboard: DashboardSync? { DashboardSync(address: dashboardURL) }
    var scanDiagnostics: Bool { didSet { defaults.set(scanDiagnostics, forKey: "scanDiagnostics") } }
    /// "system", "light" or "dark"
    var appearance: String { didSet { defaults.set(appearance, forKey: "appearance") } }
    var colorScheme: ColorScheme? { appearance == "light" ? .light : appearance == "dark" ? .dark : nil }
    var onboardingComplete: Bool { didSet { defaults.set(onboardingComplete, forKey: "onboardingComplete") } }
    var rangerMode: Bool { didSet { defaults.set(rangerMode, forKey: "rangerMode") } }
    var fieldTestMode: Bool { didSet { defaults.set(fieldTestMode, forKey: "fieldTestMode") } }
    var autoCapture: Bool { didSet { defaults.set(autoCapture, forKey: "autoCapture") } }
    var roundCoordinatesOnExport: Bool { didSet { defaults.set(roundCoordinatesOnExport, forKey: "roundCoordinatesOnExport") } }
    /// Debug builds only: pretend the phone is at the preserve.
    var simulateLocation: Bool { didSet { defaults.set(simulateLocation, forKey: "simulateLocation") } }
    var hapticsEnabled: Bool { didSet { defaults.set(hapticsEnabled, forKey: "hapticsEnabled") } }

    func resetAll() {
        for key in ["onboardingComplete", "rangerMode", "fieldTestMode", "autoCapture", "roundCoordinatesOnExport", "simulateLocation", "hapticsEnabled", "appearance", "scanDiagnostics", "dashboardURL"] {
            defaults.removeObject(forKey: key)
        }
        onboardingComplete = false; rangerMode = false; fieldTestMode = false; autoCapture = false
        roundCoordinatesOnExport = false; simulateLocation = false; hapticsEnabled = true; appearance = "system"; scanDiagnostics = false; dashboardURL = Config.defaultDashboardURL
    }
}
