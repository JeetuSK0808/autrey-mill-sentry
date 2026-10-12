import SwiftUI
import PhotosUI
import SwiftData

struct ScanView: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var vm: ScanViewModel?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showSafety = false
    @State private var showResult = false

    var body: some View {
        NavigationStack {
            Group {
                if let vm { content(vm) } else { ProgressView().task { makeViewModel() } }
            }
            .navigationTitle("Scan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSafety = true } label: { Label("Safety", systemImage: "exclamationmark.shield") }
                        .accessibilityHint("Shows trail safety reminders")
                }
            }
            .sheet(isPresented: $showSafety) { SafetySheet() }
        }
    }

    private func makeViewModel() {
        vm = ScanViewModel(classifier: app.classifier, catalog: app.catalog, location: app.location, preserve: app.preserve, settings: app.settings)
        #if DEBUG
        app.applySimulatedLocation()
        #endif
    }

    @ViewBuilder
    private func content(_ vm: ScanViewModel) -> some View {
        @Bindable var settings = app.settings
        ZStack {
            if vm.cameraDenied {
                cameraDeniedView
            } else {
                CameraPreviewView(session: vm.camera.session)
                    .ignoresSafeArea(edges: .bottom)
                framingGuide(vm)
            }
            VStack {
                guidancePill(vm)
                Spacer()
                controls(vm, settings: settings)
            }
            if vm.phase == .capturing || vm.phase == .analyzing {
                analyzingOverlay(vm)
            }
        }
        .background(.black)
        .task { await vm.startLive() }
        .onDisappear { vm.stopLive() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, vm.phase == .live { vm.camera.start() } else if phase != .active { vm.camera.stop() }
        }
        .onChange(of: vm.phase) { _, phase in showResult = (phase == .result) }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let cg = ImageLoading.cgImage(fromJPEGData: data, maxDimension: 2000) {
                    await vm.analyzePicked(cg)
                }
                pickerItem = nil
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: vm.lockHapticTick)
        .fullScreenCover(isPresented: $showResult, onDismiss: { vm.dismissResult() }) {
            if let r = vm.result { ScanResultView(result: r) { vm.dismissResult() } }
        }
        .alert("Camera problem", isPresented: Binding(get: { vm.errorMessage != nil }, set: { _ in })) {
            Button("OK") { vm.dismissResult() }
        } message: { Text(vm.errorMessage ?? "") }
    }

    private var cameraDeniedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill").font(.system(size: 44)).foregroundStyle(.white)
            Text("Camera access is off").font(.title3.bold()).foregroundStyle(.white)
            Text("Turn it on in Settings to scan live, or use a saved photo below.").multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.85))
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }.buttonStyle(.borderedProminent)
        }.padding(32)
    }

    private func framingGuide(_ vm: ScanViewModel) -> some View {
        GeometryReader { g in
            let side = min(g.size.width, g.size.height) * 0.72
            let locked: Bool = { if case .locked = vm.lockState { return true } else { return false } }()
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(locked ? Theme.leaf : .white.opacity(0.8), style: StrokeStyle(lineWidth: locked ? 4 : 2, dash: locked ? [] : [14, 10]))
                .frame(width: side, height: side)
                .position(x: g.size.width / 2, y: g.size.height * 0.42)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: locked)
                .accessibilityHidden(true)
        }
    }

    private func guidancePill(_ vm: ScanViewModel) -> some View {
        HStack(spacing: 8) {
            Image(systemName: vm.guidanceIsGood ? "leaf.fill" : "arrow.triangle.2.circlepath")
            Text(vm.guidance).font(.headline)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.ultraThinMaterial.opacity(0.9), in: Capsule())
        .background((vm.guidanceIsGood ? Theme.forest : Color.black).opacity(0.55), in: Capsule())
        .padding(.top, 12)
        .accessibilityLabel("Guidance: \(vm.guidance)")
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func controls(_ vm: ScanViewModel, settings: Bindable<SettingsStore>) -> some View {
        VStack(spacing: 14) {
            if let name = vm.liveTopName, vm.guidanceIsGood {
                Text("Seeing: \(name)").font(.subheadline.weight(.semibold)).foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6).background(.black.opacity(0.5), in: Capsule())
            }
            if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
                Button("Use sample photo") {
                    if let url = Bundle.main.url(forResource: "sample_leaf", withExtension: "jpg"), let data = try? Data(contentsOf: url),
                       let cg = ImageLoading.cgImage(fromJPEGData: data, maxDimension: 1200) {
                        Task { await vm.analyzePicked(cg, overrideQuality: .perfect) }
                    }
                }
                .buttonStyle(.bordered).tint(.white)
                .accessibilityIdentifier("scan.samplePhoto")
            }
            HStack(alignment: .center) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    VStack(spacing: 4) { Image(systemName: "photo.on.rectangle").font(.title2); Text("Photo").font(.caption2) }
                        .frame(width: 64, height: 64)
                        .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .accessibilityLabel("Choose a saved photo")
                .accessibilityIdentifier("scan.photoPicker")
                Spacer()
                Button { Task { await vm.capture() } } label: {
                    ZStack {
                        Circle().strokeBorder(.white, lineWidth: 5).frame(width: 84, height: 84)
                        Circle().fill(vm.guidanceIsGood ? Theme.leaf : .white).frame(width: 68, height: 68)
                    }
                }
                .disabled(vm.phase != .live || vm.cameraDenied)
                .accessibilityLabel("Capture")
                .accessibilityHint("Takes a photo and identifies the plant")
                .accessibilityIdentifier("scan.shutter")
                Spacer()
                Toggle(isOn: settings.autoCapture) {
                    VStack(spacing: 4) { Image(systemName: "bolt.badge.automatic").font(.title2); Text("Auto").font(.caption2) }
                }
                .toggleStyle(.button)
                .tint(Theme.leaf)
                .frame(width: 64, height: 64)
                .background(.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
                .foregroundStyle(.white)
                .accessibilityLabel("Auto capture when locked on")
            }
            .padding(.horizontal, 28)
            Text(SafetyCopy.short).font(.caption).foregroundStyle(.white.opacity(0.9)).multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .padding(.bottom, 16)
        .background(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom).allowsHitTesting(false))
    }

    private func analyzingOverlay(_ vm: ScanViewModel) -> some View {
        VStack(spacing: 12) {
            ProgressView().tint(.white).controlSize(.large)
            Text(vm.phase == .capturing ? "Capturing…" : "Identifying…").font(.headline).foregroundStyle(.white)
            if let hint = vm.locationHint { Text(hint).font(.footnote).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center) }
        }
        .padding(24)
        .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

struct SafetySheet: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("Before you scan") {
                    ForEach(SafetyCopy.lines, id: \.self) { Label($0, systemImage: "checkmark.shield") }
                }
                Section("Rare plants") {
                    Text("The scanner does not record rare or protected native plants, such as the preserve's pink lady's slipper orchids. If you photograph one, the app only says \"other plant\".")
                }
            }
            .navigationTitle("Trail safety")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}
