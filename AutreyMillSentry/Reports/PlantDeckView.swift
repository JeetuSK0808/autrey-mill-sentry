import SwiftUI
import SwiftData

/// The plant deck: every species the scanner knows as a card, marked "spotted" once you have a report of it,
/// with your own photos next to the reference photo.
struct PlantDeckView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @Query private var reports: [Report]
    @State private var section: DeckSection = .tier1
    enum DeckSection: String, CaseIterable, Identifiable { case tier1 = "Tuned", natives = "Natives", tier2 = "Broad"; var id: String { rawValue } }

    private var species: [Species] {
        switch section {
        case .tier1: return app.catalog.tier1
        case .natives: return app.catalog.natives
        case .tier2: return app.catalog.tier2
        }
    }
    private func sightings(_ s: Species) -> [Report] { reports.filter { $0.species == s.label } }
    private var spottedCount: Int { species.filter { !sightings($0).isEmpty }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Spotted \(spottedCount) of \(species.count)").font(.title3.bold()).contentTransition(.numericText())
                        Text("Save a report of a species to add it to your deck.").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    ProgressRing(progress: species.isEmpty ? 0 : Double(spottedCount) / Double(species.count))
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal)
                Picker("Section", selection: $section) { ForEach(DeckSection.allCases) { Text($0.rawValue).tag($0) } }
                    .pickerStyle(.segmented).padding(.horizontal)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(Array(species.enumerated()), id: \.element.id) { i, s in
                        NavigationLink { SpeciesDetailView(species: s) } label: {
                            DeckCard(species: s, sightings: sightings(s))
                        }
                        .buttonStyle(.plain)
                        .staggeredAppear(i)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .animation(Motion.gentle, value: section)
        }
        .navigationTitle("Plant deck")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
}

private struct DeckCard: View {
    let species: Species
    let sightings: [Report]
    @State private var photo: CGImage?
    @State private var mine: CGImage?
    private var spotted: Bool { !sightings.isEmpty }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                ZStack {
                    if let photo { Image(cg: photo).resizable().scaledToFill() }
                    else { Theme.color(for: species.tier).opacity(0.2); Image(systemName: "leaf").font(.largeTitle).foregroundStyle(Theme.color(for: species.tier)) }
                }
                .frame(height: 120).frame(maxWidth: .infinity).clipped()
                .saturation(spotted ? 1 : 0.35)
                .opacity(spotted ? 1 : 0.8)
                if let mine {
                    Image(cg: mine).resizable().scaledToFill().frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.white, lineWidth: 2))
                        .padding(6)
                        .accessibilityLabel("your photo")
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(species.displayName).font(.subheadline.weight(.semibold)).lineLimit(2)
                    if spotted { Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.forest).font(.caption).accessibilityLabel("spotted") }
                }
                Text(spotted ? "\(sightings.count) sighting\(sightings.count == 1 ? "" : "s")" : "Not spotted yet").font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10).padding(.bottom, 10)
        }
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(spotted ? Theme.color(for: species.tier).opacity(0.8) : .clear, lineWidth: 2))
        .task {
            photo = LearnPhotos.shared.image(for: species.label, maxPixel: 320)
            if let first = sightings.first { mine = PhotoStore.thumbnail(first.photoFileName, maxPixel: 120) }
        }
        .accessibilityElement(children: .combine)
    }
}

struct ProgressRing: View {
    let progress: Double
    var body: some View {
        ZStack {
            Circle().stroke(Theme.forest.opacity(0.15), lineWidth: 6)
            Circle().trim(from: 0, to: progress).stroke(Theme.forest, style: StrokeStyle(lineWidth: 6, lineCap: .round)).rotationEffect(.degrees(-90))
                .animation(Motion.gentle, value: progress)
            Text("\(Int((progress * 100).rounded()))%").font(.caption2.weight(.bold).monospacedDigit())
        }
        .accessibilityLabel("\(Int((progress * 100).rounded())) percent spotted")
    }
}
