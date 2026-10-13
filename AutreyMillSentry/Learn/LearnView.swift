import SwiftUI

struct LearnView: View {
    @Environment(AppModel.self) private var app
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Spot, Verify, Act, Tell. Every visitor becomes a sentry for the preserve. Learn the invasive plants that matter most here and the natives they are confused with.")
                        .font(.callout)
                }
                Section("Tuned species (can be confirmed by the scanner)") {
                    ForEach(Array(app.catalog.tier1.enumerated()), id: \.element.id) { i, s in
                        NavigationLink { SpeciesDetailView(species: s) } label: { SpeciesRow(species: s).staggeredAppear(i) }
                    }
                }
                Section("Native look-alikes (never reported)") {
                    ForEach(Array(app.catalog.natives.enumerated()), id: \.element.id) { i, s in
                        NavigationLink { SpeciesDetailView(species: s) } label: { SpeciesRow(species: s).staggeredAppear(i) }
                    }
                }
                Section {
                    ForEach(app.catalog.tier2) { s in
                        if let url = URL(string: s.sourceURL) {
                            Link(destination: url) {
                                VStack(alignment: .leading) { Text(s.displayName).font(.body); Text(s.scientificName).font(.caption.italic()).foregroundStyle(.secondary) }
                            }
                        }
                    }
                } header: {
                    Text("Broad coverage (always expert review)")
                } footer: {
                    Text("\(app.catalog.tier2.count) more species from the Georgia Invasive Species Council list. The scanner knows them but never calls them confirmed, because accuracy on rare classes is lower.")
                }
            }
            .navigationTitle("Learn")
        }
    }
}

struct SpeciesRow: View {
    let species: Species
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: species.tier == .native ? "leaf.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.color(for: species.tier)).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                HStack { Text(species.displayName).font(.body.weight(.semibold)); if species.documentedAtPreserve { Image(systemName: "mappin.circle.fill").foregroundStyle(Theme.forest).accessibilityLabel("documented at Autrey Mill") } }
                Text(species.scientificName).font(.caption.italic()).foregroundStyle(.secondary)
            }
        }
    }
}

struct SpeciesDetailView: View {
    @Environment(AppModel.self) private var app
    let species: Species
    @State private var showSource = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(species.displayName).font(.largeTitle.bold())
                        Text(species.scientificName).font(.title3.italic()).foregroundStyle(.secondary)
                    }
                    Spacer()
                    TierBadge(tier: species.tier)
                }
                if species.documentedAtPreserve {
                    Label("Documented at Autrey Mill by preserve volunteers (2012 list)", systemImage: "mappin.circle.fill").font(.footnote).foregroundStyle(Theme.forest)
                }
                LeafIllustration(tier: species.tier).frame(height: 120)
                block("Why it matters", species.whyItMatters).staggeredAppear(1)
                block("How to recognise it", species.howToRecognize).staggeredAppear(2)
                if !species.whatToPhotograph.isEmpty { block("What to photograph", species.whatToPhotograph) }
                if let la = species.lookAlike {
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Tell them apart: \(la.name)", systemImage: "arrow.left.arrow.right").font(.headline)
                            Text(la.tellThemApart).font(.callout)
                            if let l = la.label, let other = app.catalog.species(for: l) {
                                NavigationLink("Open \(other.displayName)") { SpeciesDetailView(species: other) }.font(.callout)
                            }
                        }
                    }
                }
                Button { showSource = true } label: { Label("Source", systemImage: "link") }.buttonStyle(.bordered)
                Text(SafetyCopy.short).font(.footnote).foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle(species.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showSource) { if let u = URL(string: species.sourceURL) { SafariView(url: u).ignoresSafeArea() } }
    }
    private func block(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(title).font(.headline); Text(text).font(.body) }
    }
}

/// A simple SwiftUI-drawn leaf so Learn has an illustration without any licensed photos.
struct LeafIllustration: View {
    let tier: SpeciesTier
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var sway = false
    var body: some View {
        illustration
            .rotationEffect(.degrees(sway ? 2.5 : -2.5), anchor: .bottomLeading)
            .onAppear { if !reduceMotion { withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) { sway = true } } }
            .popIn()
    }
    private var illustration: some View {
        GeometryReader { g in
            let w = g.size.width, h = g.size.height
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: w * 0.2, y: h * 0.8))
                    p.addQuadCurve(to: CGPoint(x: w * 0.8, y: h * 0.2), control: CGPoint(x: w * 0.25, y: h * 0.1))
                    p.addQuadCurve(to: CGPoint(x: w * 0.2, y: h * 0.8), control: CGPoint(x: w * 0.75, y: h * 0.9))
                }
                .fill(LinearGradient(colors: [Theme.leaf, Theme.color(for: tier).opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing))
                Path { p in p.move(to: CGPoint(x: w * 0.2, y: h * 0.8)); p.addLine(to: CGPoint(x: w * 0.8, y: h * 0.2)) }
                    .stroke(Theme.forest.opacity(0.6), lineWidth: 3)
            }
        }
        .accessibilityHidden(true)
    }
}
