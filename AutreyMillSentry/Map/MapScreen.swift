import SwiftUI
import MapKit
import SwiftData

/// Real preserve map: bundled OSM trails, boundary, creek and points of interest, plus report pins.
struct MapScreen: View {
    @Environment(AppModel.self) private var app
    @Query(sort: \Report.createdAt, order: .reverse) private var reports: [Report]
    @State private var position: MapCameraPosition = .region(MapScreen.preserveRegion)
    @State private var selectedReport: Report?
    @State private var selectedTrail: Trail?
    @State private var filters = ReportFilters()
    @State private var showFilters = false
    var rangerMode = false

    static let preserveRegion = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: Config.preserveCenter.latitude, longitude: Config.preserveCenter.longitude),
                                                   latitudinalMeters: 1100, longitudinalMeters: 900)
    static let bounds = MapCameraBounds(centerCoordinateBounds: MKCoordinateRegion(center: preserveRegion.center, latitudinalMeters: Config.mapPanLimitMeters * 2, longitudinalMeters: Config.mapPanLimitMeters * 2),
                                        minimumDistance: 150, maximumDistance: 6000)

    private var visibleReports: [Report] { reports.filter { filters.matches($0) } }

    var body: some View {
        NavigationStack {
            Map(position: $position, bounds: MapScreen.bounds, interactionModes: [.pan, .zoom, .rotate]) {
                if !app.preserve.boundaryCoordinates.isEmpty {
                    MapPolygon(coordinates: app.preserve.boundaryCoordinates)
                        .foregroundStyle(Theme.forest.opacity(0.08))
                        .stroke(Theme.forest, lineWidth: 2)
                }
                ForEach(app.preserve.waterways) { w in
                    if w.isPolygon {
                        MapPolygon(coordinates: w.coordinates).foregroundStyle(Theme.creek.opacity(0.35)).stroke(Theme.creek, lineWidth: 1)
                    } else {
                        MapPolyline(coordinates: w.coordinates).stroke(Theme.creek, lineWidth: 3)
                    }
                }
                ForEach(app.preserve.trails) { t in
                    MapPolyline(coordinates: t.coordinates)
                        .stroke(selectedTrail == t ? Theme.caution : Theme.bark, style: StrokeStyle(lineWidth: selectedTrail == t ? 6 : 4, lineCap: .round, lineJoin: .round))
                }
                ForEach(app.preserve.trails) { t in
                    if t.name != "Unnamed trail", let mid = t.coordinates.middle {
                        Annotation(t.name, coordinate: mid, anchor: .center) {
                            Button { selectedTrail = (selectedTrail == t ? nil : t) } label: {
                                Image(systemName: "figure.hiking").font(.caption2).padding(6)
                                    .background(Theme.bark, in: Circle()).foregroundStyle(.white)
                            }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("\(t.name) trail")
                        }
                    }
                }
                ForEach(app.preserve.pois.filter(\.isShown)) { p in
                    Annotation(p.name, coordinate: p.coordinate) {
                        Image(systemName: p.symbolName).font(.caption).padding(6)
                            .background(.thinMaterial, in: Circle())
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel(p.name)
                    }
                    .annotationTitles(.hidden)
                }
                ForEach(visibleReports) { r in
                    Annotation(r.speciesName, coordinate: CLLocationCoordinate2D(latitude: r.latitude, longitude: r.longitude)) {
                        Button { selectedReport = r } label: { StatusPin(status: r.status).opacity(r.isPractice ? 0.6 : 1) }
                            .frame(minWidth: 44, minHeight: 44)
                            .accessibilityLabel("\(r.speciesName), \(r.status.title)\(r.isPractice ? ", practice" : "")")
                            .accessibilityHint("Shows the report details")
                    }
                    .annotationTitles(.hidden)
                }
                UserAnnotation()
            }
            .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll, showsTraffic: false))
            .mapControls { MapCompass(); MapScaleView() }
            .overlay(alignment: .topLeading) { locationHint.padding(12) }
            .overlay(alignment: .bottomTrailing) { mapButtons.padding(12) }
            .overlay(alignment: .top) { if let t = selectedTrail { trailBanner(t) } }
            .navigationTitle(rangerMode ? "Ranger map" : "Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showFilters = true } label: { Label("Filters", systemImage: filters.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle") }
                }
            }
            .sheet(item: $selectedReport) { r in ReportDetailView(report: r, rangerMode: rangerMode).presentationDetents([.medium, .large]) }
            .sheet(isPresented: $showFilters) { ReportFiltersSheet(filters: $filters, catalog: app.catalog).presentationDetents([.medium, .large]) }
            .onAppear { app.location.requestWhenInUse(); app.location.start() }
            .onDisappear { app.location.stop() }
        }
    }

    private var locationHint: some View {
        Group {
            if let c = app.location.current {
                let d = app.preserve.distanceToPreserveEdge(c.point)
                if d <= Config.geofenceBufferMeters {
                    Label("You're at the preserve", systemImage: "leaf.fill")
                } else if d <= Config.nearPreserveHintMeters {
                    Label("You're \(Geo.roundedDistanceDescription(d)) from the preserve", systemImage: "location")
                } else {
                    Label("\(Geo.roundedDistanceDescription(d)) away", systemImage: "location")
                }
            } else if app.location.isDenied {
                Label("Location off. Map still works.", systemImage: "location.slash")
            }
        }
        .font(.footnote.weight(.semibold))
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(.thinMaterial, in: Capsule())
    }

    private var mapButtons: some View {
        VStack(spacing: 10) {
            Button { withAnimation { position = .region(MapScreen.preserveRegion) } } label: { Image(systemName: "tree").frame(width: 44, height: 44) }
                .background(.thinMaterial, in: Circle()).accessibilityLabel("Recenter on the preserve")
            if app.location.isAuthorized {
                Button { withAnimation { position = .userLocation(fallback: .region(MapScreen.preserveRegion)) } } label: { Image(systemName: "location.fill").frame(width: 44, height: 44) }
                    .background(.thinMaterial, in: Circle()).accessibilityLabel("Center on my location")
            }
        }
    }

    private func trailBanner(_ t: Trail) -> some View {
        HStack {
            Image(systemName: "figure.hiking")
            Text(t.name).font(.headline)
            Spacer()
            Button { selectedTrail = nil } label: { Image(systemName: "xmark.circle.fill") }.frame(minWidth: 44, minHeight: 44).accessibilityLabel("Close")
        }
        .padding(.horizontal, 12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 12).padding(.top, 48)
    }
}

extension Array where Element == CLLocationCoordinate2D {
    var middle: CLLocationCoordinate2D? { isEmpty ? nil : self[count / 2] }
}

/// Species, status and date filters shared by the map and the lists.
struct ReportFilters: Equatable {
    var species: Set<String> = []
    var statuses: Set<ReportStatus> = Set(ReportStatus.allCases)
    var from: Date? = nil
    var to: Date? = nil
    var isActive: Bool { !species.isEmpty || statuses.count != ReportStatus.allCases.count || from != nil || to != nil }
    func matches(_ r: Report) -> Bool {
        if !species.isEmpty && !species.contains(r.species) { return false }
        if !statuses.contains(r.status) { return false }
        if let from, r.createdAt < from { return false }
        if let to, r.createdAt > to.addingTimeInterval(86_400) { return false }
        return true
    }
}

struct ReportFiltersSheet: View {
    @Binding var filters: ReportFilters
    let catalog: SpeciesCatalog
    @Environment(\.dismiss) private var dismiss
    @State private var useFrom = false
    @State private var useTo = false
    @State private var from = Date().addingTimeInterval(-30 * 86_400)
    @State private var to = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Status") {
                    ForEach(ReportStatus.allCases) { s in
                        Toggle(isOn: Binding(get: { filters.statuses.contains(s) }, set: { on in if on { filters.statuses.insert(s) } else { filters.statuses.remove(s) } })) {
                            Label(s.title, systemImage: s.symbolName)
                        }
                    }
                }
                Section("Species") {
                    Toggle("All species", isOn: Binding(get: { filters.species.isEmpty }, set: { if $0 { filters.species = [] } }))
                    ForEach(catalog.tier1) { s in
                        Toggle(s.displayName, isOn: Binding(get: { filters.species.contains(s.label) }, set: { on in if on { filters.species.insert(s.label) } else { filters.species.remove(s.label) } }))
                    }
                }
                Section("Dates") {
                    Toggle("From", isOn: $useFrom)
                    if useFrom { DatePicker("From", selection: $from, displayedComponents: .date) }
                    Toggle("To", isOn: $useTo)
                    if useTo { DatePicker("To", selection: $to, displayedComponents: .date) }
                }
                Section { Button("Clear filters", role: .destructive) { filters = ReportFilters(); useFrom = false; useTo = false } }
            }
            .onChange(of: useFrom) { _, v in filters.from = v ? from : nil }
            .onChange(of: useTo) { _, v in filters.to = v ? to : nil }
            .onChange(of: from) { _, v in if useFrom { filters.from = v } }
            .onChange(of: to) { _, v in if useTo { filters.to = v } }
            .navigationTitle("Filters")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
