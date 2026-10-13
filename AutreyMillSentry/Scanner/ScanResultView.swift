import SwiftUI
import SwiftData

/// Result of one scan: one of four outcomes, honest confidence, and the save flow.
struct ScanResultView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Query(sort: \Report.createdAt, order: .reverse) private var reports: [Report]
    let result: ScanResult
    let onDone: () -> Void

    @State private var patchSize: PatchSize = .few
    @State private var note = ""
    @State private var saved: Report?
    @State private var duplicate: Report?
    @State private var reportAnyway = false
    @State private var fieldLabel = ""
    @State private var showFieldTest = false
    @State private var errorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    photo
                    Group {
                        switch result.outcome {
                        case .rescan(let reason): rescanCard(reason)
                        case .confirmedInvasive(let label, let conf): speciesCard(label: label, confidence: conf, confirmed: true)
                        case .possibleInvasive(let candidates): possibleCard(candidates)
                        case .looksNative(let label, let conf): nativeCard(label: label, confidence: conf)
                        }
                    }
                    .staggeredAppear(1)
                    if !result.outcome.isRescan || reportAnyway { saveSection.staggeredAppear(3).transition(.opacity) }
                    AIHonestyFooter().padding(.horizontal).staggeredAppear(5)
                }
                .animation(Motion.gentle, value: reportAnyway)
                .padding(.bottom, 24)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(result.outcome.isRescan ? "Try again" : "Discard") { onDone() }.fontWeight(.semibold).tint(Theme.forestDeep).accessibilityIdentifier("result.close")
                }
            }
            .alert("Could not save", isPresented: Binding(get: { errorText != nil }, set: { _ in errorText = nil })) { Button("OK") {} } message: { Text(errorText ?? "") }
            .sensoryFeedback(.success, trigger: saved?.id)
        }
    }

    private var title: String {
        switch result.outcome {
        case .rescan: return "Please rescan"
        case .confirmedInvasive: return "Invasive found"
        case .possibleInvasive: return "Needs expert review"
        case .looksNative: return "Looks native"
        }
    }

    private var photo: some View {
        CGImageView(image: result.image)
            .frame(height: 260)
            .clipped()
            .overlay(alignment: .bottomLeading) {
                if result.source == .picker { Text("From a saved photo").font(.caption).padding(6).background(.ultraThinMaterial, in: Capsule()).padding(8) }
            }
            .accessibilityLabel("The photo you scanned")
    }

    // MARK: Cards

    private func rescanCard(_ reason: RescanReason) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(reason.title, systemImage: "arrow.triangle.2.circlepath").font(.title2.bold())
            Text(reason.instruction).font(.body)
            Text(ScanDecision.tip(for: reason, candidate: result.classification.top?.label, catalog: app.catalog)).font(.callout).foregroundStyle(.secondary)
            Button { onDone() } label: { Text("Try again") }
                .primaryButton()
                .accessibilityIdentifier("result.tryAgain")
            if reason == .ambiguous && !reportAnyway {
                VStack(alignment: .leading, spacing: 6) {
                    Text("We can't recognise this one. Want staff to take a look?").font(.subheadline.weight(.semibold))
                    Button("Report anyway for expert review") { reportAnyway = true }.buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal)
    }

    private func speciesCard(label: String, confidence: Double, confirmed: Bool) -> some View {
        let s = app.catalog.species(for: label)
        return VStack(alignment: .leading, spacing: 10) {
            AdaptiveHStack { Text(app.catalog.name(for: label)).font(.title.bold()); Spacer(minLength: 0); TierBadge(tier: app.catalog.tier(of: label)).popIn(delay: 0.35) }
            if let s { Text(s.scientificName).font(.subheadline.italic()).foregroundStyle(.secondary) }
            Text(confirmed ? "Confirmed invasive by the on-device model." : "Possible invasive.").font(.headline).foregroundStyle(confirmed ? Theme.alert : Theme.caution)
            ConfidenceBar(value: confidence)
            if let s { whyBlock(s) }
            top3
        }.padding(.horizontal)
    }

    private func possibleCard(_ candidates: [ClassProbability]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack { Text("Possible invasive").font(.title.bold()); Spacer(); Image(systemName: "person.fill.questionmark").font(.title2).foregroundStyle(Theme.caution) }
            Text("Needs expert review. The model is not sure enough to name a species as fact, so this report goes to staff with the photo.").font(.body)
            if let first = candidates.first {
                Text("Most likely: \(app.catalog.name(for: first.label))").font(.headline)
                ConfidenceBar(value: first.probability)
                if let s = app.catalog.species(for: first.label) { whyBlock(s) }
            } else {
                Text("Unknown plant. Staff will identify it from your photo.").font(.headline)
            }
            top3
        }.padding(.horizontal)
    }

    private func nativeCard(label: String?, confidence: Double) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            let name = label.map { app.catalog.name(for: $0) } ?? "another plant"
            HStack { Text("Looks like \(label == nil ? "" : "native ")\(name).").font(.title2.bold()); Spacer(); Image(systemName: "leaf.circle.fill").font(.title).foregroundStyle(Theme.forest) }
            Text("No report needed.").font(.headline).foregroundStyle(Theme.forest)
            ConfidenceBar(value: confidence)
            if let label, let s = app.catalog.species(for: label), let la = s.lookAlike {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Not to be confused with \(la.name)").font(.subheadline.weight(.semibold))
                    Text(la.tellThemApart).font(.callout).foregroundStyle(.secondary)
                }
            }
            top3
            Text("Think the model is wrong? You can still send it to staff.").font(.footnote).foregroundStyle(.secondary)
        }.padding(.horizontal)
    }

    private func whyBlock(_ s: Species) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Why we think so").font(.subheadline.weight(.semibold))
            Text(s.howToRecognize).font(.callout)
            if let la = s.lookAlike {
                NavigationLink { SpeciesDetailView(species: s) } label: {
                    Label("Tell it apart from \(la.name)", systemImage: "arrow.left.arrow.right").font(.callout)
                }
            }
        }
    }

    private var top3: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Top 3").font(.caption).foregroundStyle(.secondary)
            ForEach(result.classification.top3) { p in
                HStack { Text(app.catalog.name(for: p.label)); Spacer(); Text("\(Int((p.probability * 100).rounded()))%").monospacedDigit() }.font(.callout)
            }
        }
    }

    // MARK: Save

    private var isPractice: Bool { !result.isInsidePreserve }

    private var saveSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider()
            if result.location == nil {
                Label("No location. Reports need a location to be useful, so this one is saved as practice.", systemImage: "location.slash").font(.footnote).foregroundStyle(.secondary)
            } else if isPractice {
                Label("You're outside the preserve. Reports are saved as practice only and won't be ranked.", systemImage: "mappin.slash").font(.footnote).foregroundStyle(Theme.caution)
            } else if result.lowAccuracy {
                Label("Low location accuracy (\(Int(result.horizontalAccuracy ?? 0)) m). Saved with a flag.", systemImage: "location.circle").font(.footnote).foregroundStyle(.secondary)
            } else if !result.nearestTrailName.isEmpty {
                Label("Near \(result.nearestTrailName)", systemImage: "figure.walk").font(.footnote).foregroundStyle(.secondary)
            }
            Text("Patch size").font(.subheadline.weight(.semibold))
            Picker("Patch size", selection: $patchSize) {
                ForEach(PatchSize.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented)
            Text(patchSize.detail).font(.caption).foregroundStyle(.secondary)
            TextField("Optional note (no names or personal info, please)", text: $note, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(2...4)
            if app.settings.fieldTestMode { fieldTestBlock }
            if let saved {
                Label("Saved. It's on your map and in Reports.", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.forest).font(.headline)
                    .symbolEffect(.bounce, value: saved.id)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                Button { onDone() } label: { Text("Done") }.primaryButton()
                    .accessibilityIdentifier("result.done")
                let _ = saved
            } else if let duplicate {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Same species was reported within \(Int(Config.duplicateRadiusMeters)) m in the last \(Config.duplicateWindowDays) days.").font(.subheadline)
                    Button { addToExisting(duplicate) } label: { Text("Add to existing report") }.primaryButton()
                    Button("Save as a new report") { save(force: true) }.buttonStyle(.bordered)
                }
            } else {
                Button { save(force: false) } label: { Text(saveTitle) }
                    .primaryButton()
                    .accessibilityIdentifier("result.save")
                    .transition(.opacity)
            }
        }
        .padding(.horizontal)
        .animation(Motion.spring, value: saved?.id)
        .animation(Motion.spring, value: duplicate?.id)
    }

    private var fieldTestBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Field test: true label").font(.subheadline.weight(.semibold))
            Text("Entered by a person who knows the plant. Used only to measure field accuracy.").font(.caption).foregroundStyle(.secondary)
            Picker("True label", selection: $fieldLabel) {
                Text("Not checked").tag("")
                ForEach(app.catalog.tier1 + app.catalog.natives) { Text($0.displayName).tag($0.label) }
                Text("Other plant").tag("other_plant")
                Text("Not a plant").tag("not_plant")
                ForEach(app.catalog.tier2) { Text($0.displayName).tag($0.label) }
            }
        }
    }

    private var saveTitle: String {
        switch result.outcome {
        case .looksNative: return "Send anyway for expert review"
        case .rescan: return "Save for expert review"
        default: return "Save report"
        }
    }

    private var speciesAndFlags: (label: String, name: String, confidence: Double, needsExpert: Bool) {
        switch result.outcome {
        case .confirmedInvasive(let s, let c): return (s, app.catalog.name(for: s), c, false)
        case .possibleInvasive(let cands):
            if let f = cands.first { return (f.label, app.catalog.name(for: f.label), f.probability, true) }
            return ("unknown", "Unknown plant", 0, true)
        case .looksNative(let l, let c): return (l ?? "other_plant", l.map { app.catalog.name(for: $0) } ?? "Other plant", c, true)
        case .rescan: return ("unknown", "Unknown plant", result.classification.top?.probability ?? 0, true)
        }
    }

    private func save(force: Bool) {
        let f = speciesAndFlags
        if !force, let loc = result.location, f.label != "unknown" {
            let cands = reports.map { DuplicateFinder.Candidate(id: $0.id, species: $0.species, location: $0.location, createdAt: $0.createdAt) }
            if let d = DuplicateFinder.existingReport(species: f.label, location: loc, now: .now, candidates: cands), let r = reports.first(where: { $0.id == d.id }) {
                duplicate = r; return
            }
        }
        do {
            let r = try ReportStore.create(from: result, species: f.label, speciesName: f.name, confidence: f.confidence, needsExpertReview: f.needsExpert,
                                           patchSize: patchSize, note: note, fieldTrueLabel: fieldLabel.isEmpty ? nil : fieldLabel,
                                           catalog: app.catalog, preserve: app.preserve, context: context)
            saved = r
        } catch { errorText = error.localizedDescription }
    }

    private func addToExisting(_ r: Report) {
        ReportStore.addSighting(to: r, note: note, context: context)
        saved = r
    }
}
