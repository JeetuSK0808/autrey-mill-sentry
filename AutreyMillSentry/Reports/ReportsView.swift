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

/// How a report reads at a glance: confirmed invasive (dark red), needs expert review (amber), native or other (green).
enum ReportKind {
    case invasive, review, benign
    static func of(_ r: Report, catalog: SpeciesCatalog) -> ReportKind {
        if r.needsExpertReview { return .review }
        return catalog.tier(of: r.species) == .tier1 ? .invasive : .benign
    }
    var tint: Color {
        switch self {
        case .invasive: return Color(red: 0.55, green: 0.10, blue: 0.08)
        case .review: return Theme.caution
        case .benign: return Theme.forest
        }
    }
    var title: String {
        switch self {
        case .invasive: return "Invasive"
        case .review: return "Expert review"
        case .benign: return "Native or other"
        }
    }
}

struct ReportsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \Report.createdAt, order: .reverse) private var reports: [Report]
    @State private var shareItems: [URL]?
    @State private var showSettings = false
    @State private var showDeck = false
    @State private var errorText: String?
    @State private var sort: ReportSort = .newest
    @State private var statusFilter: ReportStatus? = nil
    @State private var kindFilter: ReportKind? = nil

    private var visible: [Report] {
        var list = reports.filter { r in
            (statusFilter == nil || r.status == statusFilter!) && (kindFilter == nil || ReportKind.of(r, catalog: app.catalog) == kindFilter!)
        }
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
            Group {
                if reports.isEmpty {
                    EmptyStateView(symbol: "leaf.circle", title: "No reports yet", message: "Scan a plant and save it. Your reports appear here and on the map.")
                } else {
                    List {
                        Section {
                            summary.listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)).listRowBackground(Color.clear)
                        }
                        Section {
                            filterChips.listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0)).listRowBackground(Color.clear)
                        }
                        Section {
                            ForEach(Array(visible.enumerated()), id: \.element.id) { i, r in
                                NavigationLink { ReportDetailView(report: r, rangerMode: false) } label: { ReportRowView(report: r).staggeredAppear(i) }
                                    .listRowBackground(rowBackground(for: r))
                            }
                            .onDelete { idx in idx.map { visible[$0] }.forEach { ReportStore.delete($0, context: context, catalog: app.catalog) } }
                        } header: {
                            Text(visible.count == reports.count ? "\(reports.count) report(s)" : "\(visible.count) of \(reports.count) report(s)")
                        } footer: {
                            Text("Nothing leaves your phone until you tap Send.")
                        }
                    }
                    .animation(Motion.gentle, value: visible.map(\.id))
                }
            }
            .navigationTitle("My Reports")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showSettings = true } label: { Label("Settings", systemImage: "gearshape") }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button { showDeck = true } label: { Label("Plant deck", systemImage: "square.grid.2x2") }
                        .accessibilityIdentifier("reports.deck")
                    Menu {
                        Picker("Sort", selection: $sort) { ForEach(ReportSort.allCases) { Label($0.title, systemImage: $0.symbol).tag($0) } }
                    } label: { Label("Sort", systemImage: "arrow.up.arrow.down") }
                    Button { send(reports.filter { !$0.isPractice }) } label: { Label("Send to preserve", systemImage: "paperplane") }
                        .disabled(reports.filter { !$0.isPractice }.isEmpty)
                        .accessibilityIdentifier("reports.send")
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showDeck) { NavigationStack { PlantDeckView() } }
            .sheet(isPresented: Binding(get: { shareItems != nil }, set: { if !$0 { shareItems = nil } })) {
                if let items = shareItems { SendSheet(items: items, reports: reports.filter { !$0.isPractice }) }
            }
            .alert("Could not export", isPresented: Binding(get: { errorText != nil }, set: { _ in errorText = nil })) { Button("OK") {} } message: { Text(errorText ?? "") }
        }
    }

    private var summary: some View {
        let invasive = reports.filter { ReportKind.of($0, catalog: app.catalog) == .invasive }.count
        let review = reports.filter { $0.needsExpertReview }.count
        let treated = reports.filter { $0.status == .treated }.count
        let species = Set(reports.map(\.species)).count
        return HStack(spacing: 10) {
            statTile("\(invasive)", "invasive", ReportKind.invasive.tint)
            statTile("\(review)", "to review", ReportKind.review.tint)
            statTile("\(treated)", "treated", Theme.forest)
            statTile("\(species)", species == 1 ? "species" : "species", Theme.bark)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(invasive) invasive, \(review) to review, \(treated) treated, \(species) species")
    }

    private func statTile(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.title2.bold().monospacedDigit()).foregroundStyle(color).contentTransition(.numericText())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", selected: statusFilter == nil && kindFilter == nil, color: Theme.forest) { statusFilter = nil; kindFilter = nil }
                chip("Invasive", selected: kindFilter == .invasive, color: ReportKind.invasive.tint) { kindFilter = kindFilter == .invasive ? nil : .invasive }
                chip("Expert review", selected: kindFilter == .review, color: ReportKind.review.tint) { kindFilter = kindFilter == .review ? nil : .review }
                ForEach(ReportStatus.allCases) { s in
                    chip(s.title, selected: statusFilter == s, color: Theme.color(for: s)) { statusFilter = statusFilter == s ? nil : s }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
    }

    private func chip(_ title: String, selected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.subheadline.weight(.semibold))
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(selected ? color : color.opacity(0.12), in: Capsule())
                .foregroundStyle(selected ? .white : color)
                .frame(minHeight: 44)
        }
        .buttonStyle(.plain)
        .animation(Motion.snappy, value: selected)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func rowBackground(for r: Report) -> some View {
        let kind = ReportKind.of(r, catalog: app.catalog)
        return HStack(spacing: 0) {
            Rectangle().fill(kind.tint).frame(width: 5)
            Rectangle().fill(kind.tint.opacity(kind == .invasive ? 0.10 : 0.05))
        }
    }

    private func send(_ list: [Report]) {
        do { shareItems = try LocalOnlySync().package(list, roundCoordinates: app.settings.roundCoordinatesOnExport) }
        catch { errorText = error.localizedDescription }
    }
}

struct ReportRowView: View {
    @Environment(AppModel.self) private var app
    let report: Report
    var showPriority = false
    @State private var thumb: CGImage?
    var body: some View {
        let kind = ReportKind.of(report, catalog: app.catalog)
        HStack(spacing: 12) {
            CGImageView(image: thumb).frame(width: 56, height: 56).clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(kind.tint.opacity(0.6), lineWidth: kind == .invasive ? 2 : 0))
                .task { thumb = PhotoStore.thumbnail(report.photoFileName, maxPixel: 160) }
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(report.speciesName).font(.headline).foregroundStyle(kind == .invasive ? kind.tint : .primary)
                    if report.needsExpertReview { Image(systemName: "person.fill.questionmark").foregroundStyle(Theme.caution).accessibilityLabel("needs expert review") }
                }
                Text("\(report.createdAt.shortDescription)\(report.nearestTrailName.isEmpty ? "" : " · " + report.nearestTrailName)").font(.caption).foregroundStyle(.secondary)
                AdaptiveHStack(spacing: 6) {
                    StatusBadge(status: report.status).animation(Motion.snappy, value: report.status)
                    if report.isPractice { Text("Practice").font(.caption2.weight(.semibold)).padding(.horizontal, 6).padding(.vertical, 3).background(.quaternary, in: Capsule()) }
                    if showPriority { Text("Priority \(Int(report.priorityScore.rounded()))").font(.caption2.weight(.bold)).foregroundStyle(Theme.forest).animation(Motion.gentle, value: report.priorityScore) }
                    if !showPriority && kind == .invasive { Text("Confidence \(Int((report.confidence * 100).rounded()))%").font(.caption2.weight(.semibold)).foregroundStyle(kind.tint) }
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
                        .buttonStyle(.bordered).tint(Theme.caution).controlSize(.large)
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
