import Foundation
import UIKit
import MapKit
import SwiftData

/// One-page work order: the top 10 priorities with species, coordinates, map thumbnail, photo, patch size and why it ranked.
enum WorkOrderPDF {
    static func mapSnapshot(for r: Report, size: CGSize = CGSize(width: 220, height: 160)) async -> UIImage? {
        let opts = MKMapSnapshotter.Options()
        let coord = CLLocationCoordinate2D(latitude: r.latitude, longitude: r.longitude)
        opts.region = MKCoordinateRegion(center: coord, latitudinalMeters: 220, longitudinalMeters: 300)
        opts.size = size
        opts.pointOfInterestFilter = .excludingAll
        opts.mapType = .standard
        guard let snap = try? await MKMapSnapshotter(options: opts).start() else { return nil }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            snap.image.draw(at: .zero)
            let p = snap.point(for: coord)
            let pin = UIBezierPath(ovalIn: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14))
            UIColor.systemRed.setFill(); pin.fill()
            UIColor.white.setStroke(); pin.lineWidth = 2; pin.stroke()
        }
    }

    static func make(reports: [Report], snapshots: [UUID: UIImage], context: ModelContext, catalog: SpeciesCatalog) throws -> URL {
        let dir = try ReportExport.exportDirectory()
        let url = dir.appendingPathComponent("work-order.pdf")
        let page = CGRect(x: 0, y: 0, width: 612, height: 792)
        let all = ReportStore.all(context)
        let data = UIGraphicsPDFRenderer(bounds: page).pdfData { ctx in
            ctx.beginPage()
            var y = PDFText.draw("Autrey Mill invasive plant work order", font: .boldSystemFont(ofSize: 20), at: 36, y: 36, width: 540)
            y = PDFText.draw("Top \(reports.count) priorities by early-detection score. Generated \(Date().shortDescription) by \(Config.appName) (student project). Treatment method is the staff's decision. AI suggestions, not guarantees.", font: .systemFont(ofSize: 9.5), at: 36, y: y + 2, width: 540, color: .darkGray)
            y += 10
            for (i, r) in reports.enumerated() {
                if y > 700 { ctx.beginPage(); y = 36 }
                let top = y
                PDFText.draw("\(i + 1)", font: .boldSystemFont(ofSize: 18), at: 36, y: y, width: 30)
                if let cg = PhotoStore.thumbnail(r.photoFileName, maxPixel: 300) {
                    UIImage(cgImage: cg).draw(in: CGRect(x: 66, y: y, width: 84, height: 64))
                }
                if let snap = snapshots[r.id] { snap.draw(in: CGRect(x: 156, y: y, width: 88, height: 64)) }
                let tx: CGFloat = 252, tw: CGFloat = 324
                var ty = y
                ty = PDFText.draw("\(r.speciesName)\(r.needsExpertReview ? " (needs expert review)" : "") · \(r.patchSize.title) · score \(Int(r.priorityScore.rounded()))", font: .boldSystemFont(ofSize: 11), at: tx, y: ty, width: tw)
                ty = PDFText.draw(String(format: "%.5f, %.5f · %@ · creek %@ · %@", r.latitude, r.longitude, r.nearestTrailName.isEmpty ? "trail unknown" : r.nearestTrailName, r.distanceToCreekMeters.map { "\(Int($0)) m" } ?? "n/a", r.createdAt.formatted(date: .abbreviated, time: .omitted)), font: .systemFont(ofSize: 9), at: tx, y: ty + 1, width: tw, color: .darkGray)
                let factors = PriorityScore.score(ReportStore.rankingInput(for: r, all: all, catalog: catalog)).factors
                let why = factors.sorted { $0.points > $1.points }.prefix(3).map { "\($0.name) \(Int($0.points.rounded()))" }.joined(separator: ", ")
                ty = PDFText.draw("Why: \(why)", font: .italicSystemFont(ofSize: 9), at: tx, y: ty + 1, width: tw, color: .darkGray)
                y = max(top + 70, ty + 6)
                UIColor.lightGray.setStroke()
                let line = UIBezierPath(); line.move(to: CGPoint(x: 36, y: y - 3)); line.addLine(to: CGPoint(x: 576, y: y - 3)); line.lineWidth = 0.5; line.stroke()
            }
        }
        try data.write(to: url)
        return url
    }
}
