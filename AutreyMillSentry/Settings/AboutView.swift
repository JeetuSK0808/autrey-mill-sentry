import SwiftUI

/// Model card as shipped: numbers come only from model/eval/*.json via Resources/model_card.json.
struct ModelCard: Codable {
    struct TierMetrics: Codable {
        var classes: Int
        var top1: Double?
        var top3: Double?
        var precisionAtConfirm: Double?
        var coverageAtConfirm: Double?
        var confirmThreshold: Double?
        var testImages: Int?
    }
    var status: String                // "not_evaluated" or "evaluated"
    var modelVersion: String?
    var evaluatedOn: String?
    var testObservations: Int?
    var tier1: TierMetrics?
    var tier2: TierMetrics?
    var ece: Double?
    var notPlantRejectRate: Double?
    var hardestConfusions: [String]?
    var fieldAccuracy: Double?
    var fieldPhotos: Int?
    var dataSource: String?
    var notes: String?
}

struct AboutView: View {
    @Environment(AppModel.self) private var app
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(Config.appName).font(.title2.bold())
                    Text(Config.credit)
                    Text("Built for Autrey Mill Nature Preserve & Heritage Center, Johns Creek, Georgia. This is a student project and not an official preserve app. The preserve has not endorsed or approved it.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("How accurate is this?") { accuracyCard }
            Section("The problem") {
                Text("Invasive plants like privet, English ivy and kudzu crowd out native understory plants, which reduces the insects, berries and cover that local wildlife depend on.")
                Link("UGA Extension on Chinese privet (forms dense thickets that outcompete native plants)", destination: URL(string: "https://site.extension.uga.edu/fayette/2025/03/native-plant-awareness-week-posts")!)
                Link("Georgia Invasive Species Council plant list", destination: URL(string: SpeciesCatalog.gisc)!)
                Link("Georgia Forestry Commission Dirty Dozen (ranking weights)", destination: URL(string: "https://gatrees.org/resources/2021-dirty-dozen-top-twelve-nonnative-invasive-plants-list")!)
            }
            Section("Credits and data") {
                Text("Map data © OpenStreetMap contributors (ODbL). Base map © Apple Maps.")
                Text("Training photos: iNaturalist research-grade observations under CC0, CC BY and CC BY-NC licences. Observers are credited in the project's LICENSES file. No photos are redistributed in the app.")
                Text("Species list: Georgia Invasive Species Council (formerly GA-EPPC). Preserve species: Autrey Mill volunteer post, 2012.")
                Text("Built with Swift, SwiftUI, SwiftData, MapKit, Vision and Core ML. SF Symbols are used under Apple's terms.")
            }
        }
        .navigationTitle("About")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private var accuracyCard: some View {
        if let m = app.modelCard, m.status == "evaluated" {
            if let t = m.tier1 {
                metric("Tuned species (\(t.classes) classes)", t)
            }
            if let t = m.tier2 { metric("Broad coverage (\(t.classes) classes)", t) }
            if let ece = m.ece { row("Calibration error (ECE)", String(format: "%.3f", ece)) }
            if let r = m.notPlantRejectRate { row("Not-a-plant photos rejected", pct(r)) }
            if let n = m.testObservations { row("Held-out test set", "\(n) observations, split by observer") }
            if let f = m.fieldAccuracy, let n = m.fieldPhotos { row("Field accuracy at the preserve", "\(pct(f)) on \(n) photos") } else {
                Text("Field accuracy: not measured yet. Held-out accuracy comes from iNaturalist photos and will be lower in the field.").font(.footnote).foregroundStyle(.secondary)
            }
            if let c = m.hardestConfusions, !c.isEmpty { Text("Hardest confusions: \(c.joined(separator: "; "))").font(.footnote).foregroundStyle(.secondary) }
            if let v = m.modelVersion, let d = m.evaluatedOn { Text("Model \(v), evaluated \(d).").font(.caption).foregroundStyle(.secondary) }
        } else {
            Text("No evaluation has been run for the bundled model yet, so no accuracy numbers are shown.").foregroundStyle(.secondary)
        }
        AIHonestyFooter()
    }

    private func metric(_ title: String, _ t: ModelCard.TierMetrics) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.headline)
            if let v = t.top1 { row("Top-1 accuracy", pct(v)) }
            if let v = t.top3 { row("Top-3 accuracy", pct(v)) }
            if let p = t.precisionAtConfirm, let th = t.confirmThreshold { row("Precision of \"confirmed\" calls", "\(pct(p)) at threshold \(String(format: "%.2f", th))") }
            if let c = t.coverageAtConfirm { row("Coverage (true invasives confirmed, rest go to expert review)", pct(c)) }
        }
    }
    private func row(_ k: String, _ v: String) -> some View { HStack { Text(k).font(.callout); Spacer(); Text(v).font(.callout.monospacedDigit().weight(.semibold)) } }
    private func pct(_ v: Double) -> String { String(format: "%.1f%%", v * 100) }
}
