import Foundation
import Observation

/// What the scanner is seeing, for the on-screen overlay and the exportable log. Lives on the main actor;
/// the camera queue hands over plain values.
@MainActor
@Observable
final class ScanDiagnostics {
    struct LiveSample: Codable {
        var t: Double; var sharp: Double; var luma: Double; var clip: Double; var subject: Double; var motion: Double; var person: Bool
        var hard: String?; var soft: String?; var top: [String]; var lock: String
        var focus: Bool = false      // the live pass also looked at the salient region
        var lockP: Double = 0        // probability the lock-on tracked (top class, or combined native mass)
        var torch: Bool = false
    }
    struct StillSample: Codable { var t: Double; var source: String; var sharp: Double; var luma: Double; var clip: Double; var subject: Double; var person: Bool; var top: [String]; var outcome: String; var model: String; var similarity: Double?; var floor: Double? }

    private(set) var frames = 0
    private(set) var classified = 0
    private(set) var lastLive: LiveSample?
    private(set) var lastStill: StillSample?
    private(set) var recentLive: [LiveSample] = []
    private(set) var stills: [StillSample] = []
    var modelVersion = ""
    var cameraState = ""

    func record(live: LiveSample) {
        frames += 1
        if !live.top.isEmpty { classified += 1 }
        lastLive = live
        recentLive.append(live)
        if recentLive.count > 240 { recentLive.removeFirst(recentLive.count - 240) }
    }

    func record(still: StillSample) {
        lastStill = still
        stills.append(still)
        appendToLog(still)
    }

    var overlayText: String {
        var lines: [String] = []
        lines.append("model \(modelVersion)  frames \(frames)  classified \(classified)  \(cameraState)")
        if let l = lastLive {
            lines.append(String(format: "live sharp %.0f luma %.2f clip %.2f subj %.2f motion %.2f%@", l.sharp, l.luma, l.clip, l.subject, l.motion, l.person ? " PERSON" : ""))
            lines.append(String(format: "gate %@/%@  lock %@ p %.2f%@%@", l.hard ?? "-", l.soft ?? "-", l.lock, l.lockP, l.focus ? " focus" : "", l.torch ? " torch" : ""))
            lines.append("top " + l.top.joined(separator: " | "))
        }
        if let s = lastStill {
            lines.append(String(format: "still(%@) sharp %.0f luma %.2f subj %.2f -> %@", s.source, s.sharp, s.luma, s.subject, s.outcome))
            lines.append("still top " + s.top.joined(separator: " | ") + (s.similarity.map { String(format: "  sim %.2f/%.2f", $0, s.floor ?? 0) } ?? ""))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: log file (Application Support/scan_log.jsonl), exported from Settings
    static var logURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("scan_log.jsonl")
    }

    private func appendToLog(_ s: StillSample) {
        guard let data = try? JSONEncoder().encode(s), var line = String(data: data, encoding: .utf8) else { return }
        line += "\n"
        if let h = try? FileHandle(forWritingTo: Self.logURL) { h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); try? h.close() }
        else { try? line.write(to: Self.logURL, atomically: true, encoding: .utf8) }
    }

    /// Writes a snapshot (recent live samples + every logged still) for sharing.
    func exportSnapshot() -> URL? {
        struct Snapshot: Codable { var exportedAt: Date; var modelVersion: String; var frames: Int; var classified: Int; var recentLive: [LiveSample]; var stills: [StillSample]; var loggedStills: [StillSample] }
        var logged: [StillSample] = []
        if let text = try? String(contentsOf: Self.logURL, encoding: .utf8) {
            for line in text.split(separator: "\n") { if let d = line.data(using: .utf8), let s = try? JSONDecoder().decode(StillSample.self, from: d) { logged.append(s) } }
        }
        let snap = Snapshot(exportedAt: .now, modelVersion: modelVersion, frames: frames, classified: classified, recentLive: recentLive, stills: stills, loggedStills: logged)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("scan_diagnostics.json")
        let enc = JSONEncoder(); enc.outputFormatting = [.prettyPrinted]; enc.dateEncodingStrategy = .iso8601
        guard let data = try? enc.encode(snap) else { return nil }
        try? data.write(to: url)
        return url
    }
}
