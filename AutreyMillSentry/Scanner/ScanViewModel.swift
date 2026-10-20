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
    var embeddings: EmbeddingTable? = nil
    var diagnostics: ScanDiagnostics? = nil

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

    enum TorchMode: String { case auto, on, off }
    private(set) var torchMode: TorchMode = .auto
    var torchIsOn: Bool { camera.torchOn }
    var torchAvailable: Bool { camera.torchAvailable }

    // Live-frame state lives on the camera's serial video queue.
    @ObservationIgnored nonisolated(unsafe) private let liveClassifier: PlantClassifying
    @ObservationIgnored nonisolated private let liveCatalog: SpeciesCatalog
    @ObservationIgnored nonisolated(unsafe) private var analyzer = QualityAnalyzer()
    @ObservationIgnored nonisolated(unsafe) private var tracker = LockOnTracker(thresholds: Config.scan)
    @ObservationIgnored nonisolated(unsafe) private var liveEnabled = false
    @ObservationIgnored nonisolated(unsafe) private var autoCaptureArmed = true
    @ObservationIgnored nonisolated(unsafe) private var wasLocked = false
    @ObservationIgnored nonisolated(unsafe) private var darkFrames = 0
    @ObservationIgnored nonisolated(unsafe) private var brightFrames = 0
    @ObservationIgnored nonisolated(unsafe) private var autoTorchOn = false
    @ObservationIgnored nonisolated(unsafe) private var torchModeLive: TorchMode = .auto

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

    /// Flashlight: auto (on when the scene is dark), on, off. Tapping cycles on → off → auto.
    func cycleTorch() {
        switch torchMode {
        case .auto: torchMode = .on
        case .on: torchMode = .off
        case .off: torchMode = .auto
        }
        torchModeLive = torchMode
        switch torchMode {
        case .on: camera.setTorch(true)
        case .off: camera.setTorch(false); autoTorchOn = false
        case .auto: autoTorchOn = false; camera.setTorch(false); darkFrames = 0; brightFrames = 0
        }
    }

    nonisolated private func autoTorch(luminance: Double) {
        guard torchModeLive == .auto else { return }
        if luminance < 0.16 { darkFrames += 1; brightFrames = 0 } else if luminance > 0.45 { brightFrames += 1; darkFrames = 0 } else { darkFrames = 0; brightFrames = 0 }
        if !autoTorchOn && darkFrames >= 6 { autoTorchOn = true; camera.setTorch(true) }
        if autoTorchOn && brightFrames >= 24 { autoTorchOn = false; camera.setTorch(false) }
    }

    nonisolated private func handleFrame(_ pb: CVPixelBuffer, orientation: CGImagePropertyOrientation) {
        guard liveEnabled else { return }
        let metrics = analyzer.analyze(pixelBuffer: pb, orientation: orientation, trackMotion: true)
        autoTorch(luminance: metrics.meanLuminance)
        let t = Config.scan
        let now = Date().timeIntervalSince1970
        if let hard = ScanDecision.hardGate(metrics, thresholds: t) {
            let state = tracker.push(nil)
            wasLocked = false
            let sample = ScanDiagnostics.LiveSample(t: now, sharp: metrics.sharpness, luma: metrics.meanLuminance, clip: metrics.clippedFraction, subject: metrics.subjectFraction, motion: metrics.motion, person: metrics.personDetected, hard: hard.rawValue, soft: nil, top: [], lock: "idle")
            Task { @MainActor in self.diagnostics?.record(live: sample); self.applyLive(state: state, topName: nil, guidance: hard.liveHint, good: false, freshLock: false, autoCapture: false) }
            return
        }
        let soft = ScanDecision.softGate(metrics, thresholds: t)
        guard let cls = try? liveClassifier.classifyLive(pixelBuffer: pb, orientation: orientation), let top = cls.top else {
            let sample = ScanDiagnostics.LiveSample(t: now, sharp: metrics.sharpness, luma: metrics.meanLuminance, clip: metrics.clippedFraction, subject: metrics.subjectFraction, motion: metrics.motion, person: false, hard: nil, soft: soft?.rawValue, top: [], lock: "idle")
            Task { @MainActor in self.diagnostics?.record(live: sample) }
            return
        }
        let top3 = cls.top3.map { "\(liveCatalog.name(for: $0.label)) \(Int(($0.probability * 100).rounded()))" }
        if top.label == "not_plant" && top.probability >= t.notPlantMinProbability {
            let state = tracker.push(nil)
            wasLocked = false
            let sample = ScanDiagnostics.LiveSample(t: now, sharp: metrics.sharpness, luma: metrics.meanLuminance, clip: metrics.clippedFraction, subject: metrics.subjectFraction, motion: metrics.motion, person: false, hard: nil, soft: soft?.rawValue, top: top3, lock: "idle")
            Task { @MainActor in self.diagnostics?.record(live: sample); self.applyLive(state: state, topName: nil, guidance: (soft ?? .noPlantFound).liveHint, good: false, freshLock: false, autoCapture: false) }
            return
        }
        let state = tracker.push(top, distribution: cls.probabilities)
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
        var good = true
        switch state {
        case .locked(let label, _): guidance = "Locked on: \(liveCatalog.name(for: label)). Tap to capture."
        case .tracking:
            if let soft, soft != .tooClose { guidance = soft.liveHint; good = false } else { guidance = "Plant in view, hold steady" }
        case .idle: guidance = "Plant in view, tap to capture"
        }
        let lockText: String = { switch state { case .locked: return "locked"; case .tracking(_, let a, let n): return "tracking \(a)/\(n)"; case .idle: return "idle" } }()
        let sample = ScanDiagnostics.LiveSample(t: now, sharp: metrics.sharpness, luma: metrics.meanLuminance, clip: metrics.clippedFraction, subject: metrics.subjectFraction, motion: metrics.motion, person: false, hard: nil, soft: soft?.rawValue, top: top3, lock: lockText)
        Task { @MainActor in self.diagnostics?.record(live: sample); self.applyLive(state: state, topName: name, guidance: guidance, good: good, freshLock: freshLock, autoCapture: auto) }
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
        let live = source == .camera ? tracker.liveEvidence() : nil
        let liveWeight = Config.scan.liveEvidenceWeight
        let work = Task.detached(priority: .userInitiated) { () -> (QualityMetrics, ClassificationResult)? in
            let q = overrideQuality ?? QualityAnalyzer().analyze(image, orientation: .up, trackMotion: false)
            // Test-time augmentation: the full frame, a tighter centre crop, a mirrored copy, and a slightly zoomed crop.
            var passes: [[ClassProbability]] = []
            var version = "coreml"
            var firstEmbedding: [Float]? = nil
            for variant in TestTimeAugmentation.variants(of: image) {
                if let c = try? classifier.classify(variant, orientation: .up) {
                    passes.append(c.probabilities); version = c.modelVersion
                    if firstEmbedding == nil { firstEmbedding = c.embedding }
                }
            }
            guard !passes.isEmpty else { return nil }
            var fused = Evidence.average(passes)
            if let live, !live.isEmpty { fused = Evidence.average([fused, live], weights: [1 - liveWeight, liveWeight]) }
            return (q, ClassificationResult(probabilities: fused, modelVersion: version, embedding: firstEmbedding))
        }
        guard let (quality, classification) = await work.value else {
            errorMessage = "The photo could not be analysed."; phase = .live; liveEnabled = true; camera.start(); return
        }
        let table = embeddings
        let gate: ((String) -> (value: Double, floor: Double)?)? = (table?.isAvailable == true && classification.embedding != nil)
            ? { label in table!.similarity(of: classification.embedding!, to: label) } : nil
        let outcome = ScanDecision.decide(quality: quality, classification: classification, catalog: catalog, similarity: gate)
        if let diag = diagnostics {
            let topLabel = classification.top?.label
            let sim = topLabel.flatMap { gate?($0) }
            let outcomeText: String = { switch outcome { case .confirmedInvasive(let s, let c): return "confirmed \(s) \(Int(c * 100))"; case .possibleInvasive(let c): return "possible \(c.first?.label ?? "?")"; case .looksNative(let l, let c): return "native \(l ?? "other") \(Int(c * 100))"; case .rescan(let r): return "rescan \(r.rawValue)" } }()
            diag.record(still: ScanDiagnostics.StillSample(t: Date().timeIntervalSince1970, source: source == .camera ? "camera" : "photo", sharp: quality.sharpness, luma: quality.meanLuminance, clip: quality.clippedFraction, subject: quality.subjectFraction, person: quality.personDetected,
                                                           top: classification.top3.map { "\(catalog.name(for: $0.label)) \(Int(($0.probability * 100).rounded()))" }, outcome: outcomeText, model: classification.modelVersion, similarity: sim?.value, floor: sim?.floor))
        }

        var fix: (point: GeoPoint, accuracy: Double)?
        if !outcome.isRescan, location.isAuthorized || location.simulated != nil {
            locationHint = "Getting a precise location…"
            fix = await location.waitForFix()
            if let f = fix, f.accuracy > Config.goodAccuracyMeters {
                locationHint = "Location accuracy is \(Geo.feetDescription(f.accuracy)). The report will carry a low-accuracy flag."
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


/// Cheap augmentations of the captured still. Four passes cost about 100 ms on a modern iPhone.
enum TestTimeAugmentation {
    static func variants(of image: CGImage) -> [CGImage] {
        var out = [image]
        if let c = crop(image, fraction: 0.85) { out.append(c) }
        if let m = mirrored(image) { out.append(m) }
        if let z = crop(image, fraction: 0.7) { out.append(z) }
        return out
    }
    static func crop(_ image: CGImage, fraction: CGFloat) -> CGImage? {
        let w = CGFloat(image.width), h = CGFloat(image.height)
        let cw = w * fraction, ch = h * fraction
        return image.cropping(to: CGRect(x: (w - cw) / 2, y: (h - ch) / 2, width: cw, height: ch))
    }
    static func mirrored(_ image: CGImage) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
        ctx.translateBy(x: CGFloat(image.width), y: 0); ctx.scaleBy(x: -1, y: 1)
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return ctx.makeImage()
    }
}
