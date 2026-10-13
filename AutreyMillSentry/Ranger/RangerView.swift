import SwiftUI
import SwiftData
import MapKit

/// Staff view: prioritized work list, map, status changes, work order PDF. Demo role switch, no real authentication.
struct RangerView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query private var reports: [Report]
    @State private var filters = ReportFilters()
    @State private var showFilters = false
    @State private var workOrder: URL?
    @State private var generating = false
    @State private var errorText: String?

    private var ranked: [Report] {
        reports.filter { !$0.isPractice && filters.matches($0) }
            .sorted { ($0.priorityScore, $0.createdAt) > ($1.priorityScore, $1.createdAt) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { MapScreen(rangerMode: true) } label: { Label("Map of all reports", systemImage: "map") }
                    NavigationLink { HowWeRankView() } label: { Label("How we rank", systemImage: "list.number") }
                    Button { Task { await makeWorkOrder() } } label: {
                        HStack { Label("Export work order (top 10)", systemImage: "doc.text"); if generating { Spacer(); ProgressView() } }
                    }.disabled(ranked.isEmpty || generating)
                }
                Section {
                    if ranked.isEmpty {
                        Text("No ranked reports yet. Practice reports from outside the preserve are not ranked.").foregroundStyle(.secondary)
                    }
                    ForEach(Array(ranked.enumerated()), id: \.element.id) { i, r in
                        NavigationLink { ReportDetailView(report: r, rangerMode: true) } label: {
                            HStack(spacing: 10) {
                                Text("\(i + 1)").font(.title3.bold().monospacedDigit()).foregroundStyle(Theme.forest).frame(minWidth: 30)
                                    .contentTransition(.numericText())
                                ReportRowView(report: r, showPriority: true)
                            }
                            .staggeredAppear(i)
                        }
                        .accessibilityIdentifier("ranger.row.\(i)")
                        .swipeActions(edge: .trailing) {
                            Button { Task { await ReportStore.update(status: .treated, of: r, context: context, catalog: app.catalog) } } label: { Label("Treated", systemImage: "checkmark.seal") }.tint(Theme.forest)
                            Button { Task { await ReportStore.update(status: .confirmed, of: r, context: context, catalog: app.catalog) } } label: { Label("Confirm", systemImage: "diamond") }.tint(Theme.alert)
                            Button { Task { await ReportStore.update(status: .dismissed, of: r, context: context, catalog: app.catalog) } } label: { Label("Dismiss", systemImage: "xmark.octagon") }.tint(.gray)
                        }
                    }
                } header: {
                    Text("Priority work list")
                } footer: {
                    Text("Ranked by early-detection value: small isolated patches near the creek first. Swipe a row to change its status.")
                }
            }
            .animation(Motion.spring, value: ranked.map(\.id))
            .navigationTitle("Ranger")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showFilters = true } label: { Label("Filters", systemImage: filters.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle") }
                }
            }
            .sheet(isPresented: $showFilters) { ReportFiltersSheet(filters: $filters, catalog: app.catalog) }
            .sheet(isPresented: Binding(get: { workOrder != nil }, set: { if !$0 { workOrder = nil } })) { if let u = workOrder { ShareSheet(items: [u]) } }
            .alert("Could not export", isPresented: Binding(get: { errorText != nil }, set: { _ in errorText = nil })) { Button("OK") {} } message: { Text(errorText ?? "") }
            .onAppear { ReportStore.recomputePriorities(context: context, catalog: app.catalog) }
        }
    }

    private func makeWorkOrder() async {
        generating = true
        defer { generating = false }
        let top = Array(ranked.filter { $0.status.isOpen }.prefix(10))
        var snapshots: [UUID: UIImage] = [:]
        for r in top { if let img = await WorkOrderPDF.mapSnapshot(for: r) { snapshots[r.id] = img } }
        do { workOrder = try WorkOrderPDF.make(reports: top, snapshots: snapshots, context: context, catalog: app.catalog) }
        catch { errorText = error.localizedDescription }
    }
}

struct HowWeRankView: View {
    @Environment(\.dismiss) private var dismiss
    let w = Config.ranking
    var body: some View {
        List {
            Section {
                Text("Early detection wins. Small, isolated patches are cheap to remove now and expensive later, so they go to the top. The score is a transparent weighted sum out of 100, with the same weights for everyone.")
            }
            Section("Factors") {
                factor("Patch size", w.patchSize, "A few plants score full points, a patch 60%, a large stand 20%.")
                factor("Isolation", w.isolation, "No other open reports within \(Int(Config.isolationRadiusMeters)) m scores full points.")
                factor("Near the creek", w.creekProximity, "Full points within \(Int(w.creekFullPointsWithinMeters)) m of the creek, fading to zero at \(Int(w.creekZeroPointsBeyondMeters)) m. Water carries seeds downstream.")
                factor("Model confidence", w.confidence, "Scales from 50% to 100% calibrated confidence. Reports needing expert review count little here.")
                factor("Recent and unaddressed", w.recency, "Full points in the first \(Int(w.recencyFullPointsWithinDays)) days, fading to 30% at \(Int(w.recencyFloorAtDays)) days.")
                factor("Aggressive spreader", w.speciesAggressiveness, "Per-species weight from the Georgia Forestry Commission Dirty Dozen list (acres occupied in Georgia forests).")
            }
            Section { Text("Treated and dismissed reports score 0 and leave the list. Practice reports from outside the preserve are never ranked.") }
        }
        .navigationTitle("How we rank")
        .navigationBarTitleDisplayMode(.inline)
    }
    private func factor(_ name: String, _ max: Double, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { Text(name).font(.headline); Spacer(); Text("up to \(Int(max))").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary) }
            Text(text).font(.callout).foregroundStyle(.secondary)
        }
    }
}
