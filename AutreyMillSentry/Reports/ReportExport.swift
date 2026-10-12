import Foundation
import UIKit
import SwiftData

/// Report package: PDF summary + CSV + photos, written to a temporary folder for the share sheet or mail.
enum ReportExport {
    static func exportDirectory() throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("SentryExport-\(Int(Date().timeIntervalSince1970))", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func csv(_ reports: [Report], roundCoordinates: Bool, to dir: URL) throws -> URL {
        let url = dir.appendingPathComponent("reports.csv")
        try ReportCSV.make(reports.map(\.row), roundCoordinates: roundCoordinates).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func fieldTestCSV(_ reports: [Report], to dir: URL) throws -> URL {
        let url = dir.appendingPathComponent("field_test.csv")
        var lines = ["id,created_at,predicted_label,predicted_confidence,needs_expert_review,true_label,true_label_at,model_version"]
        let iso = ISO8601DateFormatter()
        for r in reports where r.fieldTrueLabel != nil {
            lines.append([r.id.uuidString, iso.string(from: r.createdAt), r.species, ReportCSV.fmt(r.confidence, 3), r.needsExpertReview ? "true" : "false",
                          r.fieldTrueLabel ?? "", r.fieldTrueLabelAt.map { iso.string(from: $0) } ?? "", r.modelVersion].map(ReportCSV.escape).joined(separator: ","))
        }
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func copyPhotos(_ reports: [Report], to dir: URL) -> [URL] {
        var urls: [URL] = []
        for r in reports {
            let src = PhotoStore.url(for: r.photoFileName)
            let dst = dir.appendingPathComponent("photo-\(r.id.uuidString.prefix(8)).jpg")
            if (try? FileManager.default.copyItem(at: src, to: dst)) != nil { urls.append(dst) }
        }
        return urls
    }

    /// One-page-per-report summary PDF.
    static func summaryPDF(_ reports: [Report], title: String, roundCoordinates: Bool, to dir: URL) throws -> URL {
        let url = dir.appendingPathComponent("summary.pdf")
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            var y = PDFText.draw(title, font: .boldSystemFont(ofSize: 22), at: 40, y: 40, width: 532)
            y = PDFText.draw("\(Config.appName). Generated \(Date().shortDescription). \(reports.count) report(s). AI suggestions, not guarantees. Staff make the final call.", font: .systemFont(ofSize: 10), at: 40, y: y + 4, width: 532, color: .darkGray)
            y += 12
            for r in reports {
                if y > 640 { ctx.beginPage(); y = 40 }
                y = drawReport(r, y: y, roundCoordinates: roundCoordinates)
                y += 14
            }
        }
        try data.write(to: url)
        return url
    }

    static func drawReport(_ r: Report, y startY: CGFloat, roundCoordinates: Bool, x: CGFloat = 40, width: CGFloat = 532) -> CGFloat {
        var y = startY
        let lat = roundCoordinates ? ReportCSV.round(r.latitude, Config.exportRoundingDecimals) : r.latitude
        let lon = roundCoordinates ? ReportCSV.round(r.longitude, Config.exportRoundingDecimals) : r.longitude
        if let cg = PhotoStore.thumbnail(r.photoFileName, maxPixel: 400) {
            let img = UIImage(cgImage: cg)
            let h: CGFloat = 110, w = h * img.size.width / max(img.size.height, 1)
            img.draw(in: CGRect(x: x, y: y, width: min(w, 150), height: h))
        }
        let tx = x + 160
        var ty = y
        ty = PDFText.draw("\(r.speciesName)\(r.needsExpertReview ? " (needs expert review)" : "")", font: .boldSystemFont(ofSize: 14), at: tx, y: ty, width: width - 160)
        ty = PDFText.draw("Status: \(r.status.title)   Patch: \(r.patchSize.title)   Priority: \(String(format: "%.0f", r.priorityScore))/100", font: .systemFont(ofSize: 11), at: tx, y: ty + 2, width: width - 160)
        ty = PDFText.draw(String(format: "Location: %.5f, %.5f (±%.0f m)%@", lat, lon, max(r.horizontalAccuracy, 0), r.lowAccuracy ? " low accuracy" : ""), font: .systemFont(ofSize: 11), at: tx, y: ty + 2, width: width - 160)
        ty = PDFText.draw("Near: \(r.nearestTrailName.isEmpty ? "unknown trail" : r.nearestTrailName)   Creek: \(r.distanceToCreekMeters.map { "\(Int($0)) m" } ?? "n/a")   Reported: \(r.createdAt.shortDescription)", font: .systemFont(ofSize: 11), at: tx, y: ty + 2, width: width - 160)
        ty = PDFText.draw("Confidence \(Int((r.confidence * 100).rounded()))% (model \(r.modelVersion))\(r.isPractice ? "   PRACTICE (outside preserve)" : "")", font: .systemFont(ofSize: 11), at: tx, y: ty + 2, width: width - 160)
        if !r.note.isEmpty { ty = PDFText.draw("Note: \(r.note)", font: .italicSystemFont(ofSize: 11), at: tx, y: ty + 2, width: width - 160) }
        y = max(y + 114, ty)
        return y
    }
}

enum PDFText {
    @discardableResult
    static func draw(_ text: String, font: UIFont, at x: CGFloat, y: CGFloat, width: CGFloat, color: UIColor = .black) -> CGFloat {
        let style = NSMutableParagraphStyle(); style.lineBreakMode = .byWordWrapping
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
        let rect = (text as NSString).boundingRect(with: CGSize(width: width, height: 2000), options: [.usesLineFragmentOrigin], attributes: attrs, context: nil)
        (text as NSString).draw(in: CGRect(x: x, y: y, width: width, height: ceil(rect.height)), withAttributes: attrs)
        return y + ceil(rect.height)
    }
}

/// Local-first sending. A free-tier backend could implement this later; for now the package goes through the share sheet / Mail.
protocol ReportSyncing {
    func package(_ reports: [Report], roundCoordinates: Bool) throws -> [URL]
}

struct LocalOnlySync: ReportSyncing {
    func package(_ reports: [Report], roundCoordinates: Bool) throws -> [URL] {
        let dir = try ReportExport.exportDirectory()
        var items: [URL] = []
        items.append(try ReportExport.summaryPDF(reports, title: "Invasive plant reports for Autrey Mill", roundCoordinates: roundCoordinates, to: dir))
        items.append(try ReportExport.csv(reports, roundCoordinates: roundCoordinates, to: dir))
        items.append(contentsOf: ReportExport.copyPhotos(reports, to: dir))
        return items
    }
}
