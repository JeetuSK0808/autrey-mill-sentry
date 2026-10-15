import Foundation
import SwiftData

/// Talks to the preserve dashboard (dashboard/ in this repo, deployed on Vercel). Upload is explicit (the Send screen);
/// status checks run when the app comes to the foreground so the "Tell" step is real.
struct DashboardSync {
    let baseURL: URL

    init?(address: String) {
        var s = address.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return nil }
        if !s.hasPrefix("http") { s = "https://" + s }
        guard let u = URL(string: s), u.host != nil else { return nil }
        baseURL = u
    }

    struct Ack: Decodable { var id: String; var status: String; var statusUpdatedAt: String?; var duplicate: Bool? }

    /// Multipart POST of the report JSON and its JPEG. Idempotent on the server by report id.
    func upload(_ report: Report, catalog: SpeciesCatalog) async throws -> Ack {
        let photoURL = PhotoStore.url(for: report.photoFileName)
        let photo = try Data(contentsOf: photoURL)
        let species = catalog.species(for: report.species)
        let iso = ISO8601DateFormatter()
        var body: [String: Any] = [
            "id": report.id.uuidString.lowercased(), "createdAt": iso.string(from: report.createdAt),
            "latitude": report.latitude, "longitude": report.longitude, "horizontalAccuracy": report.horizontalAccuracy,
            "species": report.species, "speciesName": report.speciesName, "confidence": report.confidence,
            "top3": report.top3.map { ["label": $0.label, "probability": $0.probability] },
            "needsExpertReview": report.needsExpertReview, "patchSize": report.patchSize.rawValue, "note": report.note,
            "nearestTrailName": report.nearestTrailName, "modelVersion": report.modelVersion, "lowAccuracy": report.lowAccuracy,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
        ]
        if let d = report.distanceToCreekMeters { body["distanceToCreekMeters"] = d }
        if let species { body["scientificName"] = species.scientificName; body["tier"] = species.tier.rawValue; body["aggressiveness"] = species.aggressiveness }
        let json = try JSONSerialization.data(withJSONObject: body)
        let boundary = "sentry-\(UUID().uuidString)"
        var data = Data()
        func field(_ name: String, _ value: Data, filename: String? = nil, type: String) {
            data.append("--\(boundary)\r\n".data(using: .utf8)!)
            var disp = "Content-Disposition: form-data; name=\"\(name)\""
            if let filename { disp += "; filename=\"\(filename)\"" }
            data.append((disp + "\r\nContent-Type: \(type)\r\n\r\n").data(using: .utf8)!)
            data.append(value); data.append("\r\n".data(using: .utf8)!)
        }
        field("report", json, type: "application/json")
        field("photo", photo, filename: "\(report.id.uuidString.lowercased()).jpg", type: "image/jpeg")
        data.append("--\(boundary)--\r\n".data(using: .utf8)!)
        var req = URLRequest(url: baseURL.appendingPathComponent("api/reports"))
        req.httpMethod = "POST"
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 60
        let (resp, http) = try await URLSession.shared.upload(for: req, from: data)
        guard let code = (http as? HTTPURLResponse)?.statusCode else { throw URLError(.badServerResponse) }
        guard (200..<300).contains(code) else {
            let msg = (try? JSONSerialization.jsonObject(with: resp) as? [String: Any])?["error"] as? String
            throw NSError(domain: "DashboardSync", code: code, userInfo: [NSLocalizedDescriptionKey: msg ?? "Upload failed (\(code))."])
        }
        return try JSONDecoder().decode(Ack.self, from: resp)
    }

    func status(of remoteID: String) async throws -> String {
        var req = URLRequest(url: baseURL.appendingPathComponent("api/reports/\(remoteID)/status"))
        req.timeoutInterval = 20
        let (data, http) = try await URLSession.shared.data(for: req)
        guard (http as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
        return try JSONDecoder().decode(Ack.self, from: data).status
    }

    /// Sends every unsent non-practice report. Returns (sent, failed).
    @MainActor
    func sendAll(_ reports: [Report], catalog: SpeciesCatalog, context: ModelContext) async -> (sent: Int, failed: Int, lastError: String?) {
        var sent = 0, failed = 0; var lastError: String?
        for r in reports where !r.isPractice && r.remoteID == nil {
            do {
                let ack = try await upload(r, catalog: catalog)
                r.remoteID = ack.id; r.remoteStatus = ack.status; r.sentAt = .now; r.lastRemoteCheck = .now
                sent += 1
            } catch { failed += 1; lastError = error.localizedDescription }
        }
        try? context.save()
        return (sent, failed, lastError)
    }

    /// The Tell step: pull staff status changes for reports that were sent, and apply them locally
    /// (a change to "treated" schedules the local notification through ReportStore).
    @MainActor
    func refreshStatuses(_ reports: [Report], catalog: SpeciesCatalog, context: ModelContext) async -> Int {
        var changed = 0
        for r in reports {
            guard let id = r.remoteID else { continue }
            if let last = r.lastRemoteCheck, Date().timeIntervalSince(last) < 60 { continue }
            guard let s = try? await status(of: id) else { continue }
            r.lastRemoteCheck = .now
            if s != r.remoteStatus {
                r.remoteStatus = s
                if let st = ReportStatus(rawValue: s), st != r.status { await ReportStore.update(status: st, of: r, context: context, catalog: catalog); changed += 1 }
            }
        }
        try? context.save()
        return changed
    }
}
