import SwiftUI
import SwiftData

enum ReportSort: String, CaseIterable, Identifiable {
    case newest, oldest, priority, species, status
    var id: String { rawValue }
    var title: String {
        switch self {
        case .newest: return "Newest first"
        case .oldest: return "Oldest first"
        case .priority: return "Highest priority"
        case .species: return "Species A to Z"
        case .status: return "Status"
        }
    }
    var symbol: String {
        switch self {
        case .newest: return "clock"
        case .oldest: return "clock.arrow.circlepath"
        case .priority: return "flame"
        case .species: return "textformat.abc"
        case .status: return "checkmark.seal"
        }
    }
}

struct ReportsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \Report.createdAt, order: .reverse) private var reports: [Report]
    @State private var shareItems: [URL]?
    @State private var showSettings = false
    @State private var errorText: String?
    @State private var sort: ReportSort = .newest

    private var sorted: [Report] {
        var list = reports
        switch sort {
        case .newest: list.sort { $0.createdAt > $1.createdAt }
        case .oldest: list.sort { $0.createdAt < $1.createdAt }
        case .priority: list.sort { ($0.priorityScore, $0.createdAt) > ($1.priorityScore, $1.createdAt) }
        case .species: list.sort { $0.speciesName.localizedCaseInsensitiveCompare($1.speciesName) == .orderedAscending }
        case .status: list.sort { ($0.status.rawValue, $0.createdAt) < ($1.status.rawValue, $1.createdAt) }
        }
        return list
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { PlantDeckView(embedded: true) } label: { DeckEntryCard(spotted: Set(reports.map(\.species)).count, total: app.catalog.tier1.count + app.catalog.natives.count + app.catalog.tier2.count) }
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("reports.deck")
                }
                if reports.isEmpty {
                    Section {
                        EmptyStateView(symbol: "leaf.circle", title: "No reports yet", message: "Scan a plant and save it. Your reports appear here and on the map.")
                            .listRowBackground(Color.clear)
                    }
                } else {
                    Section {
                        ForEach(Array(sorted.enumerated()), id: \.element.id) { i, r in
                            NavigationLink { ReportDetailView(report: r, rangerMode: false) } label: { ReportRowView(report: r).staggeredAppear(i) }
                        }
                        .onDelete { idx in idx.map { sorted[$0] }.forEach { ReportStore.delete($0, context: context, catalog: app.catalog) } }
                    } footer: {
                        Text("\(reports.count) report(s). Nothing leaves your phone until you tap Send.")
                    }
                }
            }
            .navigationTitle("My Reports")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Picker("Sort", selection: $sort) { ForEach(ReportSort.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) } }
                    } label: { Label("Sort", systemImage: "arrow.up.arrow.down") }
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

/// The plant deck entry at the top of Reports.
private struct DeckEntryCard: View {
    let spotted: Int
    let total: Int
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.forest)
                Image(systemName: "square.grid.2x2.fill").font(.title2).foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text("Plant deck").font(.headline)
                Text("Spotted \(spotted) of \(total) species").font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            ProgressRing(progress: total == 0 ? 0 : Double(spotted) / Double(total)).frame(width: 40, height: 40)
        }
        .padding(14)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.forest.opacity(0.25), lineWidth: 1))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Plant deck, spotted \(spotted) of \(total) species")
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
                    if showPriority { Text("Priority \(Int(report.priorityScore.rounded()))").font(.caption2.weight(.bold)).foregroundStyle(Theme.forest).animation(Motion.gentle, value: report.priorityScore) }
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
    @State private var showStaffWaiver = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Your report package").font(.title2.bold())
                Label("summary.pdf", systemImage: "doc.richtext")
                Label("reports.csv", systemImage: "tablecells")
                Label("\(max(items.count - 2, 0)) photo(s), EXIF location stripped", systemImage: "photo.stack")
                if app.settings.roundCoordinatesOnExport { Label("Coordinates rounded to about 330 ft (Settings)", systemImage: "location.circle") }
                Spacer()
                if Config.rangerEmailIsSet && MailComposer.canSend {
                    Button { showMail = true } label: { Label("Email the preserve", systemImage: "envelope") }
                        .primaryButton()
                } else {
                    Text(Config.rangerEmailIsSet ? "Mail is not set up on this phone. Use Share instead." : "The preserve's report address is not set yet. Use Share to send it any way you like.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Button { showShare = true } label: { Label("Share…", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).padding(.vertical, 8) }
                    .buttonStyle(.bordered).controlSize(.large)
                VStack(alignment: .leading, spacing: 4) {
                    Button { showStaffWaiver = true } label: { Label("Share with preserve staff", systemImage: "antenna.radiowaves.left.and.right").frame(maxWidth: .infinity).padding(.vertical, 8) }
                        .buttonStyle(.bordered).controlSize(.large)
                        .accessibilityIdentifier("reports.staffShare")
                    Text("Preview. A direct line to staff does not exist yet. Nothing is uploaded.").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationTitle("Send to preserve")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .sheet(isPresented: $showShare, onDismiss: { ReportStore.markSent(reports, context: context) }) { ShareSheet(items: items) }
            .sheet(isPresented: $showMail, onDismiss: { ReportStore.markSent(reports, context: context) }) {
                MailComposer(to: Config.rangerEmail, subject: "Invasive plant reports from Mill Sentry", body: "Attached: \(reports.count) report(s) from the Autrey Mill Sentry app.", attachments: items)
            }
            .alert("Not live yet", isPresented: $showStaffWaiver) {
                Button("OK") {}
            } message: {
                Text("Direct sharing with preserve staff is planned (a free database the preserve can review). It is not built yet, so nothing was uploaded. Your reports stay on this phone. Use Share or Email to send the package.")
            }
        }
    }
}
