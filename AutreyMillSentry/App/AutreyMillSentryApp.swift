import SwiftUI
import SwiftData

@main
struct AutreyMillSentryApp: App {
    @State private var app = AppModel()
    let container: ModelContainer

    init() {
        let uiTesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        let config = ModelConfiguration(isStoredInMemoryOnly: uiTesting)
        do { container = try ModelContainer(for: Report.self, configurations: config) }
        catch { fatalError("Could not create the data store: \(error)") }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .modelContainer(container)
                .tint(Theme.forest)
                .preferredColorScheme(app.settings.colorScheme)
        }
    }
}

/// App-wide services and bundled data, injected once.
@MainActor
@Observable
final class AppModel {
    let settings = SettingsStore()
    let catalog: SpeciesCatalog
    let preserve = PreserveData.shared
    let location = LocationService()
    let classifier: PlantClassifying
    let embeddings = EmbeddingTable()
    let modelCard: ModelCard?
    let visitInfo: VisitInfo?

    init() {
        var species = SpeciesCatalog.builtIn
        if let url = Bundle.main.url(forResource: "tier2_species", withExtension: "json"), let data = try? Data(contentsOf: url),
           let t2 = try? JSONDecoder().decode([Species].self, from: data) {
            species += t2
        }
        catalog = SpeciesCatalog(species: species)
        classifier = ClassifierFactory.make(catalog: catalog)
        modelCard = Bundle.main.url(forResource: "model_card", withExtension: "json").flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode(ModelCard.self, from: $0) }
        visitInfo = Bundle.main.url(forResource: "visit_info", withExtension: "json").flatMap { try? Data(contentsOf: $0) }.flatMap { try? JSONDecoder().decode(VisitInfo.self, from: $0) }
        if ProcessInfo.processInfo.arguments.contains("-uiTesting") { settings.resetAll() }
        if ProcessInfo.processInfo.arguments.contains("-skipOnboarding") { settings.onboardingComplete = true }
        if ProcessInfo.processInfo.arguments.contains("-simulateLocation") { settings.simulateLocation = true }
        if ProcessInfo.processInfo.arguments.contains("-rangerMode") { settings.rangerMode = true }
        applySimulatedLocation()
    }

    func applySimulatedLocation() {
        #if DEBUG
        location.simulated = settings.simulateLocation ? Config.preserveCenter : nil
        #else
        location.simulated = nil
        #endif
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var app
    @State private var showLaunch: Bool = {
        let args = ProcessInfo.processInfo.arguments
        return !args.contains("-uiTesting") || args.contains("-showLaunch")
    }()
    var body: some View {
        ZStack {
            Group {
                if app.settings.onboardingComplete {
                    RootTabView().transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    NavigationStack { OnboardingView() }.transition(.opacity)
                }
            }
            .animation(Motion.gentle, value: app.settings.onboardingComplete)
            if showLaunch {
                LaunchOverlay { showLaunch = false }
                    .zIndex(1)
            }
        }
    }
}

struct RootTabView: View {
    @Environment(AppModel.self) private var app
    @State private var tab: Tab = .scan
    enum Tab: Hashable { case map, scan, reports, learn, visit, ranger }

    var body: some View {
        TabView(selection: $tab) {
            MapScreen().tabItem { Label("Map", systemImage: "map") }.tag(Tab.map)
            ReportsView().tabItem { Label("Reports", systemImage: "list.bullet.rectangle") }.tag(Tab.reports)
            ScanView().tabItem { Label("Scan", systemImage: "camera.viewfinder") }.tag(Tab.scan)
            LearnView().tabItem { Label("Learn", systemImage: "book") }.tag(Tab.learn)
            if app.settings.rangerMode {
                RangerView().tabItem { Label("Ranger", systemImage: "person.badge.shield.checkmark") }.tag(Tab.ranger)
            } else {
                VisitView().tabItem { Label("Visit", systemImage: "signpost.right") }.tag(Tab.visit)
            }
        }
    }
}
