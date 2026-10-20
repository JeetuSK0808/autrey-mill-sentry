import SwiftUI
import SwiftData

struct LearnView: View {
    @Environment(AppModel.self) private var app
    @State private var query = ""

    private func filtered(_ list: [Species]) -> [Species] {
        query.isEmpty ? list : list.filter { $0.displayName.localizedCaseInsensitiveContains(query) || $0.scientificName.localizedCaseInsensitiveContains(query) }
    }
    private var filteredTier2: [Species] { filtered(app.catalog.tier2) }
    private var filteredLocal: [Species] { filtered(app.catalog.localNatives) }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LearnHeroCard()
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(Array(app.catalog.tier1.enumerated()), id: \.element.id) { i, s in
                        NavigationLink { SpeciesDetailView(species: s) } label: { SpeciesRow(species: s).staggeredAppear(i) }
                    }
                } header: {
                    sectionHeader("Tuned species", "The scanner can confirm these", Theme.alert)
                }
                Section {
                    ForEach(Array(app.catalog.lookAlikeNatives.enumerated()), id: \.element.id) { i, s in
                        NavigationLink { SpeciesDetailView(species: s) } label: { SpeciesRow(species: s).staggeredAppear(i) }
                    }
                } header: {
                    sectionHeader("Native look-alikes", "Never reported, often confused", Theme.forest)
                }
                if !app.catalog.localNatives.isEmpty {
                    Section {
                        ForEach(filteredLocal) { s in
                            NavigationLink { SpeciesDetailView(species: s) } label: { SpeciesRow(species: s, compact: true) }
                        }
                    } header: {
                        sectionHeader("Common natives nearby", "\(app.catalog.localNatives.count) plants the scanner knows by name, never reported", Theme.forest)
                    }
                }
                Section {
                    ForEach(filteredTier2) { s in
                        NavigationLink { SpeciesDetailView(species: s) } label: { SpeciesRow(species: s, compact: true) }
                    }
                } header: {
                    sectionHeader("Broad coverage", "\(app.catalog.tier2.count) more listed invasives, always expert review", Theme.caution)
                }
            }
            .listStyle(.insetGrouped)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search \(app.catalog.tier2.count + app.catalog.localNatives.count) species")
            .navigationTitle("Learn")
        }
    }

    private func sectionHeader(_ title: String, _ subtitle: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 4, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline).foregroundStyle(.primary).textCase(nil)
                Text(subtitle).font(.caption).foregroundStyle(.secondary).textCase(nil)
            }
        }
        .padding(.vertical, 4)
    }
}

/// Top of Learn: the loop in one card, over the preserve-green gradient.
private struct LearnHeroCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Spot · Verify · Act · Tell").font(.caption.weight(.bold)).foregroundStyle(.white.opacity(0.85)).tracking(1.5)
            Text("Know the invaders. Know their look-alikes.").font(.title2.bold()).foregroundStyle(.white)
            Text("Every species here is on the Georgia Invasive Species Council list or is a native it gets mistaken for. The photos are real, from iNaturalist observers in the Southeast.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.9))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(LinearGradient(colors: [Color(red: 0.07, green: 0.30, blue: 0.20), Theme.forest, Color(red: 0.2, green: 0.55, blue: 0.36)], startPoint: .topLeading, endPoint: .bottomTrailing))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "leaf.fill").font(.system(size: 90)).foregroundStyle(.white.opacity(0.08)).rotationEffect(.degrees(-20)).offset(x: 10, y: 14)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .popIn()
    }
}

struct SpeciesRow: View {
    let species: Species
    var compact = false
    @State private var thumb: CGImage?
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                if let thumb {
                    Image(cg: thumb).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: [Theme.color(for: species.tier).opacity(0.5), Theme.color(for: species.tier).opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: species.tier == .native ? "leaf.fill" : "exclamationmark.triangle.fill").foregroundStyle(.white)
                }
            }
            .frame(width: compact ? 40 : 56, height: compact ? 40 : 56)
            .clipShape(RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: compact ? 10 : 14, style: .continuous).strokeBorder(Theme.color(for: species.tier).opacity(0.6), lineWidth: 2))
            .task { thumb = LearnPhotos.shared.image(for: species.label, maxPixel: 160) }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(species.displayName).font(compact ? .body : .body.weight(.semibold))
                    if species.documentedAtPreserve { Image(systemName: "mappin.circle.fill").foregroundStyle(Theme.forest).accessibilityLabel("documented at Autrey Mill") }
                }
                Text(species.scientificName).font(.caption.italic()).foregroundStyle(.secondary)
            }
        }
    }
}

struct SpeciesDetailView: View {
    @Environment(AppModel.self) private var app
    @Query private var reports: [Report]
    let species: Species
    @State private var showSource = false
    @State private var showInat = false
    @State private var hero: CGImage?

    private var myReports: [Report] { reports.filter { $0.species == species.label } }
    private var photo: LearnPhoto? { LearnPhotos.shared.photo(for: species.label) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroHeader
                VStack(alignment: .leading, spacing: 16) {
                    if species.documentedAtPreserve {
                        Label("Documented at Autrey Mill by preserve volunteers (2012 list)", systemImage: "mappin.circle.fill").font(.footnote.weight(.semibold)).foregroundStyle(Theme.forest)
                    }
                    if let photo {
                        Text(photo.credit).font(.caption2).foregroundStyle(.secondary)
                    }
                    block("Why it matters", species.whyItMatters).staggeredAppear(1)
                    if !species.howToRecognize.isEmpty { block("How to recognise it", species.howToRecognize).staggeredAppear(2) }
                    if !species.whatToPhotograph.isEmpty { block("What to photograph", species.whatToPhotograph).staggeredAppear(3) }
                    if species.tier == .tier2 { tier2Facts.staggeredAppear(2) }
                    if let la = species.lookAlike { lookAlikeCard(la).staggeredAppear(4) }
                    if !myReports.isEmpty { myPhotos.staggeredAppear(5) }
                    HStack(spacing: 10) {
                        Button { showSource = true } label: { Label("Source", systemImage: "link") }.buttonStyle(.bordered)
                        if species.inatURL != nil { Button { showInat = true } label: { Label("Photos on iNaturalist", systemImage: "photo.on.rectangle.angled") }.buttonStyle(.bordered) }
                    }
                    Text(SafetyCopy.short).font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 24)
        }
        .ignoresSafeArea(edges: .top)
        .navigationTitle(species.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .sheet(isPresented: $showSource) { if let u = URL(string: species.sourceURL) { SafariView(url: u).ignoresSafeArea() } }
        .sheet(isPresented: $showInat) { if let u = species.inatURL { SafariView(url: u).ignoresSafeArea() } }
        .task { hero = LearnPhotos.shared.image(for: species.label, maxPixel: 1200) }
    }

    private var heroHeader: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let hero {
                    Image(cg: hero).resizable().scaledToFill()
                } else {
                    LeafIllustration(tier: species.tier).padding(40).background(Theme.color(for: species.tier).opacity(0.15))
                }
            }
            .frame(height: 320)
            .frame(maxWidth: .infinity)
            .clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.15), .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 6) {
                TierBadge(tier: species.tier, onPhoto: true)
                Text(species.displayName).font(.largeTitle.bold()).foregroundStyle(.white)
                Text(species.scientificName).font(.title3.italic()).foregroundStyle(.white.opacity(0.9))
            }
            .padding(16)
        }
        .frame(height: 320)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(species.displayName), \(species.scientificName)")
    }

    private var tier2Facts: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Label("Listed by the Georgia Invasive Species Council", systemImage: "checkmark.seal").font(.subheadline.weight(.semibold))
                if species.aggressiveness >= 0.4 {
                    Label("On the Georgia Forestry Commission Dirty Dozen (acres occupied in Georgia forests)", systemImage: "flame").font(.subheadline)
                }
                Text("The app treats this species as broad coverage: a scan can flag it as a possible invasive for staff to check, but never calls it confirmed, because the model saw fewer photos of it than of the tuned species.").font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    private func lookAlikeCard(_ la: LookAlike) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Tell them apart: \(la.name)", systemImage: "arrow.left.arrow.right").font(.headline)
                if let l = la.label, let other = app.catalog.species(for: l) {
                    HStack(spacing: 10) {
                        comparisonTile(species)
                        Image(systemName: "arrow.left.arrow.right").foregroundStyle(.secondary)
                        comparisonTile(other)
                    }
                }
                Text(la.tellThemApart).font(.callout)
                if let l = la.label, let other = app.catalog.species(for: l) {
                    NavigationLink("Open \(other.displayName)") { SpeciesDetailView(species: other) }.font(.callout)
                }
            }
        }
    }

    private func comparisonTile(_ s: Species) -> some View {
        VStack(spacing: 4) {
            ZStack {
                if let img = LearnPhotos.shared.image(for: s.label, maxPixel: 300) { Image(cg: img).resizable().scaledToFill() }
                else { Theme.color(for: s.tier).opacity(0.2) }
            }
            .frame(height: 90).frame(maxWidth: .infinity).clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(s.displayName).font(.caption.weight(.semibold)).lineLimit(2).multilineTextAlignment(.center)
        }
    }

    private var myPhotos: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Your sightings (\(myReports.count))").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(myReports) { r in
                        NavigationLink { ReportDetailView(report: r, rangerMode: app.settings.rangerMode) } label: {
                            ReportThumb(report: r)
                        }
                    }
                }
            }
        }
    }

    private func block(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) { Text(title).font(.headline); Text(text).font(.body) }
    }
}

/// Small thumbnail of a report's photo with its status pin.
struct ReportThumb: View {
    let report: Report
    @State private var thumb: CGImage?
    var body: some View {
        ZStack(alignment: .topTrailing) {
            CGImageView(image: thumb).frame(width: 110, height: 110).clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            StatusPin(status: report.status, size: 22).padding(6)
        }
        .task { thumb = PhotoStore.thumbnail(report.photoFileName, maxPixel: 240) }
        .accessibilityLabel("\(report.speciesName), \(report.createdAt.shortDescription)")
    }
}

/// A simple SwiftUI-drawn leaf, the fallback when no photo is bundled.
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
