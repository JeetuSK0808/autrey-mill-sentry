import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var confirmDelete = false
    @State private var fieldCSV: URL?
    @State private var diagURL: URL?
    @State private var deleted = false

    var body: some View {
        @Bindable var settings = app.settings
        NavigationStack {
            Form {
                Section {
                    Toggle("I'm preserve staff (Ranger view)", isOn: $settings.rangerMode)
                    Text("A demo role switch for the Ranger tab. There is no login and no real authentication in this version.").font(.caption).foregroundStyle(.secondary)
                } header: { Text("Roles") }

                Section {
                    Picker("Appearance", selection: $settings.appearance) {
                        Text("System").tag("system"); Text("Light").tag("light"); Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                } header: { Text("Appearance") }

                Section {
                    Toggle("Auto-capture when locked on", isOn: $settings.autoCapture)
                    Toggle("Haptics", isOn: $settings.hapticsEnabled)
                } header: { Text("Scanner") }

                Section {
                    Toggle("Field Test mode", isOn: $settings.fieldTestMode)
                    Text("After each scan, a person who knows the plant records the true label. Exports a CSV so field accuracy can be measured honestly.").font(.caption).foregroundStyle(.secondary)
                    if settings.fieldTestMode {
                        Button("Export field test CSV") { exportFieldCSV() }
                    }
                } header: { Text("Evaluation") }

                Section {
                    Toggle("Round coordinates to about 100 m on export", isOn: $settings.roundCoordinatesOnExport)
                    Text("Precise coordinates are stored for staff. Rounding is for anything meant to be public.").font(.caption).foregroundStyle(.secondary)
                    NavigationLink("How your data is used") { PrivacyView() }
                    Button("Delete all my data", role: .destructive) { confirmDelete = true }
                    if deleted { Label("All reports and photos deleted.", systemImage: "checkmark").font(.footnote).foregroundStyle(Theme.forest) }
                } header: { Text("Privacy") }

                Section {
                    Toggle("Scan diagnostics overlay", isOn: $settings.scanDiagnostics)
                    Text("Shows what the scanner measures on each frame (sharpness, light, subject size, motion, top guesses). Use it when a scan does not behave.").font(.caption).foregroundStyle(.secondary)
                    Button("Export scan diagnostics") { diagURL = app.diagnostics.exportSnapshot() }
                    #if DEBUG
                    Toggle("Simulate location at the preserve", isOn: $settings.simulateLocation)
                        .onChange(of: app.settings.simulateLocation) { _, _ in app.applySimulatedLocation() }
                    #endif
                } header: { Text("Developer") }

                Section {
                    NavigationLink("About, accuracy and credits") { AboutView() }
                    Text(Config.credit).font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.buttonStyle(.borderedProminent).tint(Theme.forestDeep) } }
            .confirmationDialog("Delete every report and photo on this phone? This cannot be undone.", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete all my data", role: .destructive) { ReportStore.deleteAll(context: context); deleted = true }
            }
            .sheet(isPresented: Binding(get: { fieldCSV != nil }, set: { if !$0 { fieldCSV = nil } })) { if let u = fieldCSV { ShareSheet(items: [u]) } }
            .sheet(isPresented: Binding(get: { diagURL != nil }, set: { if !$0 { diagURL = nil } })) { if let u = diagURL { ShareSheet(items: [u]) } }
        }
    }

    private func exportFieldCSV() {
        if let dir = try? ReportExport.exportDirectory() { fieldCSV = try? ReportExport.fieldTestCSV(ReportStore.all(context), to: dir) }
    }
}

struct PrivacyView: View {
    var body: some View {
        List {
            Section("In plain English") {
                Text("Mill Sentry has no accounts. It never asks for your name, email or phone number, and it has no analytics, no advertising SDK and no tracking of any kind.")
                Text("When you save a report, the photo and its location are stored only on this phone. The photo is re-saved without any camera or GPS metadata.")
                Text("Nothing is sent anywhere until you tap Send to preserve. Then you choose how it goes (Mail or the share sheet) and what is in it.")
                Text("Location is used only while the app is open, to place reports on the map. There is no background location.")
                Text("Scans with a person in the frame are refused. Please do not photograph people, especially children.")
                Text("Notes are free text. Please leave out names and personal details.")
                Text("Delete all my data in Settings removes every report and photo immediately.")
            }
            Section("Permissions") {
                Label("Camera: scanning plants live", systemImage: "camera")
                Label("Location (while using): pinning reports", systemImage: "location")
                Label("Notifications: only if staff mark a report treated, asked at that moment", systemImage: "bell")
            }
            Section("Audience") {
                Text("This app is for general audiences and collects no personal information. It is a student project built for Autrey Mill Nature Preserve and is not an official preserve app.")
            }
        }
        .navigationTitle("How your data is used")
        .navigationBarTitleDisplayMode(.inline)
    }
}
