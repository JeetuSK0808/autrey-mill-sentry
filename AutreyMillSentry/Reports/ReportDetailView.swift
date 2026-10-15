import SwiftUI
import SwiftData
import MapKit

struct ReportDetailView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var report: Report
    let rangerMode: Bool
    @State private var image: CGImage?
    @State private var shareItems: [URL]?
    @State private var confirmDelete = false
    @State private var showRanking = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                CGImageView(image: image).frame(height: 240).clipped()
                    .task { image = PhotoStore.load(report.photoFileName) }
                    .accessibilityLabel("Report photo")
                VStack(alignment: .leading, spacing: 8) {
                    HStack { Text(report.speciesName).font(.title.bold()); Spacer(); StatusBadge(status: report.status) }
                    if let s = app.catalog.species(for: report.species) { Text(s.scientificName).font(.subheadline.italic()).foregroundStyle(.secondary) }
                    if report.needsExpertReview { Label("Needs expert review", systemImage: "person.fill.questionmark").foregroundStyle(Theme.caution).font(.subheadline.weight(.semibold)) }
                    if report.isPractice { Label("Practice report (outside the preserve or no location)", systemImage: "mappin.slash").font(.subheadline).foregroundStyle(.secondary) }
                    ConfidenceBar(value: report.confidence)
                }.padding(.horizontal)

                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        row("Reported", report.createdAt.shortDescription)
                        row("Patch size", report.patchSize.title)
                        row("Nearest trail", report.nearestTrailName.isEmpty ? "Unknown" : report.nearestTrailName)
                        row("Distance to creek", report.distanceToCreekMeters.map { Geo.roundedDistanceDescription($0) } ?? "n/a")
                        row("Location", String(format: "%.5f, %.5f (±%@)%@", report.latitude, report.longitude, Geo.feetDescription(max(report.horizontalAccuracy, 0)), report.lowAccuracy ? " low accuracy" : ""))
                        row("Status updated", report.statusUpdatedAt.shortDescription)
                        if report.additionalSightings > 0 { row("Extra sightings", "\(report.additionalSightings)") }
                        if let sent = report.sentAt { row("Sent", sent.shortDescription) }
                        if report.remoteID != nil { row("Preserve dashboard", "received" + (report.remoteStatus.map { ", staff status: \($0)" } ?? "")) }
                        row("Model", report.modelVersion)
                        if !report.note.isEmpty { row("Note", report.note) }
                        if let t = report.fieldTrueLabel { row("Field true label", app.catalog.name(for: t)) }
                    }
                }.padding(.horizontal)

                if !report.isPractice {
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack { Text("Priority \(Int(report.priorityScore.rounded()))/100").font(.headline); Spacer(); Button("How we rank") { showRanking = true }.font(.subheadline) }
                            ForEach(PriorityScore.score(ReportStore.rankingInput(for: report, all: ReportStore.all(context), catalog: app.catalog)).factors) { f in
                                HStack { Text(f.name).font(.caption); Spacer(); Text("\(Int(f.points.rounded()))/\(Int(f.maxPoints))").font(.caption.monospacedDigit()) }
                            }
                        }
                    }.padding(.horizontal)
                }

                if rangerMode { rangerActions.padding(.horizontal) }

                HStack {
                    Button { share() } label: { Label("Share", systemImage: "square.and.arrow.up") }.buttonStyle(.bordered)
                    Spacer()
                    Button(role: .destructive) { confirmDelete = true } label: { Label("Delete", systemImage: "trash") }.buttonStyle(.bordered)
                }.padding(.horizontal)
                AIHonestyFooter().padding(.horizontal)
            }.padding(.bottom, 24)
        }
        .navigationTitle("Report")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) { if let i = shareItems { ShareSheet(items: i) } }
        .sheet(isPresented: $showRanking) { NavigationStack { HowWeRankView() } }
        .confirmationDialog("Delete this report and its photo?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { ReportStore.delete(report, context: context, catalog: app.catalog); dismiss() }
        }
    }

    private var rangerActions: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text("Staff action").font(.headline)
                Text("Treatment method is the staff's decision. The app does not recommend one.").font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(ReportStatus.allCases) { s in
                        Button { Task { await ReportStore.update(status: s, of: report, context: context, catalog: app.catalog) } } label: {
                            Label(s.title, systemImage: s.symbolName).font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered).tint(Theme.color(for: s))
                        .disabled(report.status == s)
                        .accessibilityIdentifier("ranger.status.\(s.rawValue)")
                    }
                }
                if report.status == .treated { Text("The reporter was notified on this device.").font(.caption).foregroundStyle(Theme.forest) }
            }
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack(alignment: .top) { Text(k).font(.caption).foregroundStyle(.secondary).frame(width: 120, alignment: .leading); Text(v).font(.caption); Spacer() }
    }

    private func share() {
        shareItems = try? LocalOnlySync().package([report], roundCoordinates: app.settings.roundCoordinatesOnExport)
    }
}
