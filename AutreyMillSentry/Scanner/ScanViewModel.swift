import Foundation
import CoreGraphics
import CoreVideo
import ImageIO
import Observation

/// Everything the scanner decided about one captured image, ready for the result screen.
struct ScanResult {
    var outcome: ScanOutcome
    var image: CGImage
    var quality: QualityMetrics
    var classification: ClassificationResult
    var location: GeoPoint?
    var horizontalAccuracy: Double?
    var lowAccuracy: Bool
    var isInsidePreserve: Bool
    var nearestTrailName: String
    var distanceToCreekMeters: Double?
    var source: Source
    enum Source { case camera, picker }

    var topInvasiveCandidate: String? {
        switch outcome {
        case .confirmedInvasive(let s, _): return s
        case .possibleInvasive(let c): return c.first?.label
        default: return nil
        }
    }
}

@MainActor
@Observable
final class ScanViewModel {
    enum Phase: Equatable { case idle, live, capturing, analyzing, result }

    let camera = CameraService()
    let classifier: PlantClassifying
    let catalog: SpeciesCatalog
    let location: LocationService
    let preserve: PreserveData
    let settings: SettingsStore

    private(set) var phase: Phase = .idle
    private(set) var guidance = "Point the camera at a plant"
    private(set) var guidanceIsGood = false
    private(set) var lockState: LockOnTracker.State = .idle
    private(set) var liveTopName: String?
    private(set) var result: ScanResult?
    private(set) var errorMessage: String?
    private(set) var locationHint: String?
    private(set) var cameraDenied = false
    var lockHapticTick = 0   // bumped once per fresh lock so the view can play haptics

    // Live-frame state lives on the camera's serial video queue.
    @ObservationIgnored nonisolated(unsafe) private let liveClassifier: PlantClassifying
    @ObservationIgnored nonisolated private let liveCatalog: SpeciesCatalog
    @ObservationIgnored nonisolated(unsafe) private var analyzer = QualityAnalyzer()
    @ObservationIgnored nonisolated(unsafe) private var tracker = LockOnTracker(thresholds: Config.scan)
    @ObservationIgnored nonisolated(unsafe) private var liveEnabled = false
    @ObservationIgnored nonisolated(unsafe) private var autoCaptureArmed = true
    @ObservationIgnored nonisolated(unsafe) private var wasLocked = false

    init(classifier: PlantClassifying, catalog: SpeciesCatalog, location: LocationService, preserve: PreserveData, settings: SettingsStore) {
        self.classifier = classifier
        self.catalog = catalog
        self.location = location
        self.preserve = preserve
        self.settings = settings
        self.liveClassifier = classifier
        self.liveCatalog = catalog
        camera.onFrame = { [weak self] pb, orientation in self?.handleFrame(pb, orientation: orientation) }
    }

    // MARK: Live
    func startLive() async {
        guard await camera.requestAccess() else { cameraDenied = true; phase = .idle; return }
        cameraDenied = false
        location.requestWhenInUse()
        location.start()
        analyzer.reset(); tracker.reset(); autoCaptureArmed = true; wasLocked = false
        liveEnabled = true
        phase = .live
        camera.start()
    }

    func stopLive() { liveEnabled = false; camera.stop(); location.stop() }

    nonisolated private func handleFrame(_ pb: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
        guard liveEnabled else { return }
        let metrics = analyzer.analyze(pixelBuffer: pb, orientation: orientation, trackMotion: true)
        if let gate = ScanDecision.qualityGate(metrics) {
            let state = tracker.push(nil)
            wasLocked = false
            Task { @MainActor in self.applyLive(state: state, topName: nil, guidance: gate.liveHint, good: false, freshLock: false, autoCapture: false) }
            return
        }
        guard let cls = try? liveClassifier.classify(pixelBuffer: pb, orientation: orientation), let top = cls.top else { return }
        if top.label == "not_plant" && top.probability >= Config.scan.notPlantMinProbability {
            let state = tracker.push(nil)
            wasLocked = false
            Task { @MainActor in self.applyLive(state: state, topName: nil, guidance: RescanReason.noPlantFound.liveHint, good: false, freshLock: false, autoCapture: false) }
            return
        }
        let state = tracker.push(top)
        let name = liveCatalog.name(for: top.label)
        var freshLock = false, auto = false
        switch state {
        case .locked:
            freshLock = !wasLocked
            wasLocked = true
            if autoCaptureArmed { auto = true; autoCaptureArmed = false }
        case .tracking, .idle:
            wasLocked = false
            autoCaptureArmed = true
        }
        let guidance: String
        switch state {
        case .locked(let label, _): guidance = "Locked on: \(liveCatalog.name(for: label)). Tap to capture."
        case .tracking: guidance = "Plant in view, hold steady"
        case .idle: guidance = "Plant in view, tap to capture"
        }
        Task { @MainActor in self.applyLive(state: state, topName: name, guidance: guidance, good: true, freshLock: freshLock, autoCapture: auto) }
    }

    private func applyLive(state: LockOnTracker.State, topName: String?, guidance g: String, good: Bool, freshLock: Bool, autoCapture: Bool) {
        guard phase == .live else { return }
        lockState = state
        liveTopName = topName
        if guidance != g { guidance = g }
        guidanceIsGood = good
        if freshLock { lockHapticTick += 1 }
        if autoCapture && settings.autoCapture { Task { await capture() } }
    }

    // MARK: Capture
    func capture() async {
        guard phase == .live else { return }
        phase = .capturing
        liveEnabled = false
        do {
            let image = try await camera.capturePhoto()
            camera.stop()
            await analyze(image, source: .camera)
        } catch {
            errorMessage = error.localizedDescription
            liveEnabled = true
            phase = .live
            camera.start()
        }
    }

    func analyzePicked(_ image: CGImage, overrideQuality: QualityMetrics? = nil) async {
        liveEnabled = false
        camera.stop()
        await analyze(image, source: .picker, overrideQuality: overrideQuality)
    }

    private func analyze(_ image: CGImage, source: ScanResult.Source, overrideQuality: QualityMetrics? = nil) async {
        phase = .analyzing
        locationHint = nil
        let classifier = self.classifier
        let catalog = self.catalog
        let work = Task.detached(priority: .userInitiated) { () -> (QualityMetrics, ClassificationResult)? in
            let q = overrideQuality ?? QualityAnalyzer().analyze(image, orientation: .up, trackMotion: false)
            guard let c = try? classifier.classify(image, orientation: .up) else { return nil }
            return (q, c)
        }
        guard let (quality, classification) = await work.value else {
            errorMessage = "The photo could not be analysed."; phase = .live; liveEnabled = true; camera.start(); return
        }
        let outcome = ScanDecision.decide(quality: quality, classification: classification, catalog: catalog)

        var fix: (point: GeoPoint, accuracy: Double)?
        if !outcome.isRescan, location.isAuthorized || location.simulated != nil {
            locationHint = "Getting a precise location…"
            fix = await location.waitForFix()
            if let f = fix, f.accuracy > Config.goodAccuracyMeters {
                locationHint = "Location accuracy is \(Int(f.accuracy)) m. The report will carry a low-accuracy flag."
            } else { locationHint = nil }
        }
        let inside = fix.map { preserve.isInsidePreserve($0.point) } ?? false
        let trail = fix.flatMap { preserve.nearestTrail(to: $0.point)?.name } ?? ""
        let creek = fix.flatMap { preserve.distanceToCreek(from: $0.point) }
        result = ScanResult(outcome: outcome, image: image, quality: quality, classification: classification,
                            location: fix?.point, horizontalAccuracy: fix?.accuracy,
                            lowAccuracy: (fix?.accuracy ?? 999) > Config.goodAccuracyMeters,
                            isInsidePreserve: inside, nearestTrailName: trail, distanceToCreekMeters: creek, source: source)
        phase = .result
    }

    func dismissResult() {
        result = nil
        errorMessage = nil
        tracker.reset(); analyzer.reset(); autoCaptureArmed = true; wasLocked = false
        liveEnabled = true
        phase = .live
        camera.start()
    }
}
