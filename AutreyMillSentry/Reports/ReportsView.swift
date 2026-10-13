import SwiftUI
import SwiftData

struct ReportsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \Report.createdAt, order: .reverse) private var reports: [Report]
    @State private var shareItems: [URL]?
    @State private var showSettings = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            Group {
                if reports.isEmpty {
                    EmptyStateView(symbol: "leaf.circle", title: "No reports yet", message: "Scan a plant and save it. Your reports appear here and on the map.")
                } else {
                    List {
                        Section {
                            ForEach(Array(reports.enumerated()), id: \.element.id) { i, r in
                                NavigationLink { ReportDetailView(report: r, rangerMode: false) } label: { ReportRowView(report: r).staggeredAppear(i) }
                            }
                            .onDelete { idx in idx.map { reports[$0] }.forEach { ReportStore.delete($0, context: context, catalog: app.catalog) } }
                        } footer: {
                            Text("\(reports.count) report(s). Nothing leaves your phone until you tap Send.")
                        }
                    }
                }
            }
            .navigationTitle("My Reports")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { send(reports.filter { !$0.isPractice }) } label: { Label("Send to preserve", systemImage: "paperplane") }
                        .disabled(reports.filter { !$0.isPractice }.isEmpty)
                        .accessibilityIdentifier("reports.send")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) {
                if let items = shareItems { SendSheet(items: items, reports: reports.filter { !$0.isPractice }) }
            }
            .alert("Could not export", isPresented: Binding(get: { errorText != nil }, set: { _ in errorText = nil })) { Button("OK") {} } message: { Text(errorText ?? "") }
        }
    }

    private func send(_ list: [Report]) {
        do { shareItems = try LocalOnlySync().package(list, roundCoordinates: app.settings.roundCoordinatesOnExport) }
        catch { errorText = error.localizedDescription }
    }
}

struct ReportRowView: View {
    let report: Report
    var showPriority = false
    @State private var thumb: CGImage?
    var body: some View {
        HStack(spacing: 12) {
            CGImageView(image: thumb).frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 10))
                .task { thumb = PhotoStore.thumbnail(report.photoFileName, maxPixel: 160) }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(report.speciesName).font(.headline)
                    if report.needsExpertReview { Image(systemName: "person.fill.questionmark").foregroundStyle(Theme.caution).accessibilityLabel("needs expert review") }
                }
                Text("\(report.createdAt.shortDescription)\(report.nearestTrailName.isEmpty ? "" : " · " + report.nearestTrailName)").font(.caption).foregroundStyle(.secondary)
                AdaptiveHStack(spacing: 6) {
                    StatusBadge(status: report.status).animation(Motion.snappy, value: report.status)
                    if report.isPractice { Text("Practice").font(.caption2.weight(.semibold)).padding(.horizontal, 6).padding(.vertical, 3).background(.quaternary, in: Capsule()) }
                    if showPriority { Text("Priority \(Int(report.priorityScore.rounded()))").font(.caption2.weight(.bold)).foregroundStyle(Theme.forest).contentTransition(.numericText()).animation(Motion.gentle, value: report.priorityScore) }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

/// Share sheet for the report package, with Mail pre-addressed to the preserve once the address is set.
struct SendSheet: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let items: [URL]
    let reports: [Report]
    @State private var showShare = false
    @State private var showMail = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Your report package").font(.title2.bold())
                Label("summary.pdf", systemImage: "doc.richtext")
                Label("reports.csv", systemImage: "tablecells")
                Label("\(items.count - 2) photo(s), EXIF location stripped", systemImage: "photo.stack")
                if app.settings.roundCoordinatesOnExport { Label("Coordinates rounded to about 100 m (Settings)", systemImage: "location.circle") }
                Spacer()
                if Config.rangerEmailIsSet && MailComposer.canSend {
                    Button { showMail = true } label: { Label("Email the preserve", systemImage: "envelope").frame(maxWidth: .infinity).padding(.vertical, 8) }
                        .buttonStyle(.borderedProminent).tint(Theme.forest).controlSize(.large)
                } else {
                    Text(Config.rangerEmailIsSet ? "Mail is not set up on this phone. Use Share instead." : "The preserve's report address is not set yet. Use Share to send it any way you like.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Button { showShare = true } label: { Label("Share…", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).padding(.vertical, 8) }
                    .buttonStyle(.bordered).controlSize(.large)
            }
            .padding()
            .navigationTitle("Send to preserve")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .sheet(isPresented: $showShare, onDismiss: { ReportStore.markSent(reports, context: context) }) { ShareSheet(items: items) }
            .sheet(isPresented: $showMail, onDismiss: { ReportStore.markSent(reports, context: context) }) {
                MailComposer(to: Config.rangerEmail, subject: "Invasive plant reports from Mill Sentry", body: "Attached: \(reports.count) report(s) from the Autrey Mill Sentry app.", attachments: items)
            }
        }
    }
}
