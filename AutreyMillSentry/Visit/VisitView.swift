import SwiftUI
import MapKit

struct VisitInfo: Codable {
    var address: String
    var phone: String
    var groundsHours: String
    var visitorCenterHours: String
    var admission: String
    var groups: String
    var acres: String
    var runBy: String
    var eventsURL: String
    var websiteURL: String
    var retrievedOn: String
    var sourceURL: String
}

struct VisitView: View {
    @Environment(AppModel.self) private var app
    @State private var showEvents = false
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let v = app.visitInfo {
                        Text("Autrey Mill Nature Preserve & Heritage Center").font(.title.bold())
                        Card {
                            VStack(alignment: .leading, spacing: 10) {
                                Label(v.address, systemImage: "mappin.and.ellipse")
                                Link(destination: URL(string: "tel:\(v.phone.filter { $0.isNumber })")!) { Label(v.phone, systemImage: "phone").frame(minHeight: 44, alignment: .leading) }
                                Label("\(v.acres) · \(v.admission)", systemImage: "leaf")
                                Label(v.groups, systemImage: "person.3")
                                Label(v.runBy, systemImage: "building.2")
                            }
                        }
                        Card {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Hours").font(.headline)
                                Label("Grounds and trails: \(v.groundsHours)", systemImage: "figure.walk")
                                Label("Visitor Center and Farm Museum: \(v.visitorCenterHours)", systemImage: "door.left.hand.open")
                                Text("From \(v.websiteURL), retrieved \(v.retrievedOn). Check the website before you go.").font(.caption).foregroundStyle(Theme.muted)
                            }
                        }
                        Button { directions() } label: { Label("Directions in Apple Maps", systemImage: "car").frame(maxWidth: .infinity).padding(.vertical, 8) }
                            .buttonStyle(.borderedProminent).tint(Theme.forest).controlSize(.large).staggeredAppear(2)
                        Button { showEvents = true } label: { Label("Events and programs", systemImage: "calendar").frame(maxWidth: .infinity).padding(.vertical, 8) }
                            .buttonStyle(.bordered).controlSize(.large)
                        Card {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Trail safety").font(.headline)
                                ForEach(SafetyCopy.lines, id: \.self) { Label($0, systemImage: "checkmark.shield").font(.callout) }
                            }
                        }
                        Text("This app is a student project built for the preserve. It is not an official preserve app.").font(.footnote).foregroundStyle(.secondary)
                    } else {
                        Text("Visit information is not bundled in this build.").foregroundStyle(.secondary)
                    }
                }.padding()
            }
            .navigationTitle("Visit")
            .sheet(isPresented: $showEvents) { if let u = URL(string: app.visitInfo?.eventsURL ?? "https://autreymill.org/special-events/") { SafariView(url: u).ignoresSafeArea() } }
        }
    }

    private func directions() {
        let coord = CLLocationCoordinate2D(latitude: Config.preserveCenter.latitude, longitude: Config.preserveCenter.longitude)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: coord))
        item.name = "Autrey Mill Nature Preserve"
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }
}
