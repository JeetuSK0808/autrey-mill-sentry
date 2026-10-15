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
                if let vm { ScanContent(vm: vm, pickerItem: $pickerItem, showResult: $showResult) } else { ProgressView().task { makeViewModel() } }
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
        let model = ScanViewModel(classifier: app.classifier, catalog: app.catalog, location: app.location, preserve: app.preserve, settings: app.settings)
        model.embeddings = app.embeddings
        model.diagnostics = app.diagnostics
        app.diagnostics.modelVersion = app.classifier.modelVersion
        vm = model
        app.applySimulatedLocation()
    }
}

/// The live scanner. Kept as its own view so each piece type-checks quickly.
private struct ScanContent: View {
    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase
    let vm: ScanViewModel
    @Binding var pickerItem: PhotosPickerItem?
    @Binding var showResult: Bool

    var body: some View {
        stack
            .background(.black)
            .task { await vm.startLive() }
            .onDisappear { vm.stopLive() }
            .onChange(of: scenePhase) { _, phase in scenePhaseChanged(phase) }
            .onChange(of: vm.phase) { _, phase in showResult = (phase == .result) }
            .onChange(of: pickerItem) { _, item in loadPicked(item) }
            .sensoryFeedback(.impact(weight: .medium), trigger: vm.lockHapticTick)
            .fullScreenCover(isPresented: $showResult, onDismiss: { vm.dismissResult() }) { resultCover }
            .alert("Camera problem", isPresented: errorBinding) {
                Button("OK") { vm.dismissResult() }
            } message: {
                Text(vm.errorMessage ?? "")
            }
    }

    private var stack: some View {
        ZStack {
            if vm.cameraDenied {
                CameraDeniedView()
            } else {
                CameraPreviewView(session: vm.camera.session).ignoresSafeArea(edges: .bottom)
                FramingGuide(locked: isLocked)
            }
            VStack {
                GuidancePill(text: vm.guidance, good: vm.guidanceIsGood)
                Spacer()
                ScanControls(vm: vm, pickerItem: $pickerItem)
            }
            if vm.phase == .capturing || vm.phase == .analyzing {
                AnalyzingOverlay(capturing: vm.phase == .capturing, hint: vm.locationHint)
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
            CaptureFlash(trigger: vm.phase == .capturing)
            if app.settings.scanDiagnostics {
                VStack { Spacer().frame(height: 70); DiagnosticsOverlay(text: app.diagnostics.overlayText); Spacer() }
            }
        }
        .animation(Motion.snappy, value: vm.phase)
    }

    private var isLocked: Bool {
        if case .locked = vm.lockState { return true }
        return false
    }

    @ViewBuilder private var resultCover: some View {
        if let r = vm.result {
            ScanResultView(result: r) { showResult = false }
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(get: { vm.errorMessage != nil }, set: { _ in })
    }

    private func scenePhaseChanged(_ phase: ScenePhase) {
        if phase == .active {
            if vm.phase == .live { vm.camera.start() }
        } else {
            vm.camera.stop()
        }
    }

    private func loadPicked(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let cg = ImageLoading.cgImage(fromJPEGData: data, maxDimension: 2000) {
                await vm.analyzePicked(cg)
            }
            pickerItem = nil
        }
    }
}

private struct DiagnosticsOverlay: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, design: .monospaced))
            .foregroundStyle(.white)
            .padding(8)
            .background(Color.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true)
    }
}

private struct CameraDeniedView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "camera.fill").font(.system(size: 44)).foregroundStyle(.white)
            Text("Camera access is off").font(.title3.bold()).foregroundStyle(.white)
            Text("Turn it on in Settings to scan live, or use a saved photo below.")
                .multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.85))
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(32)
    }
}

private struct FramingGuide: View {
    let locked: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dashPhase: CGFloat = 0
    @State private var ripple = false
    var body: some View {
        GeometryReader { g in
            let side = min(g.size.width, g.size.height) * 0.72
            let center = CGPoint(x: g.size.width / 2, y: g.size.height * 0.42)
            ZStack {
                // lock-on ripple
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(Theme.leaf, lineWidth: 3)
                    .frame(width: side, height: side)
                    .scaleEffect(ripple ? 1.18 : 1)
                    .opacity(ripple ? 0 : 0.9)
                    .position(center)
                    .opacity(locked ? 1 : 0)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(locked ? Theme.leaf : Color.white.opacity(0.85),
                                  style: StrokeStyle(lineWidth: locked ? 4 : 2, dash: locked ? [] : [14, 10], dashPhase: dashPhase))
                    .frame(width: side, height: side)
                    .scaleEffect(locked ? 1.03 : 1)
                    .position(center)
                    .animation(reduceMotion ? nil : Motion.spring, value: locked)
            }
            .accessibilityHidden(true)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) { dashPhase = -24 }
        }
        .onChange(of: locked) { _, isLocked in
            guard isLocked, !reduceMotion else { return }
            ripple = false
            withAnimation(.easeOut(duration: 0.7)) { ripple = true }
        }
    }
}

private struct GuidancePill: View {
    let text: String
    let good: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: good ? "leaf.fill" : "arrow.triangle.2.circlepath")
                .contentTransition(.symbolEffect(.replace))
            Text(text).font(.headline)
                .contentTransition(.opacity)
                .id(text)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background((good ? Theme.forest : Color.black).opacity(0.7), in: Capsule())
        .padding(.top, 12)
        .animation(Motion.snappy, value: text)
        .animation(Motion.snappy, value: good)
        .accessibilityLabel("Guidance: \(text)")
        .accessibilityAddTraits(.updatesFrequently)
    }
}

private struct ScanControls: View {
    @Environment(AppModel.self) private var app
    @Environment(\.dynamicTypeSize) private var typeSize
    let vm: ScanViewModel
    @Binding var pickerItem: PhotosPickerItem?
    private var compact: Bool { typeSize.isAccessibilitySize }

    var body: some View {
        VStack(spacing: 14) {
            if let name = vm.liveTopName, vm.guidanceIsGood {
                Text("Seeing: \(name)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.5), in: Capsule())
                    .contentTransition(.opacity)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            if ProcessInfo.processInfo.arguments.contains("-uiTesting") {
                SamplePhotoButton(vm: vm)
            }
            HStack(alignment: .center) {
                photoButton
                Spacer()
                shutter
                Spacer()
                torchButton
            }
            .padding(.horizontal, 28)
            if !compact {
                Text(SafetyCopy.short)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .padding(.bottom, 16)
        .background { LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom).allowsHitTesting(false) }
        .animation(Motion.snappy, value: vm.liveTopName)
    }

    private var photoButton: some View {
        PhotosPicker(selection: $pickerItem, matching: .images) {
            VStack(spacing: 4) {
                Image(systemName: "photo.on.rectangle").font(.title2)
                if !compact { Text("Photo").font(.caption2) }
            }
            .frame(minWidth: 64, minHeight: 64)
            .background(Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
        }
        .accessibilityLabel("Choose a saved photo")
        .accessibilityIdentifier("scan.photoPicker")
    }

    private var shutter: some View {
        let locked: Bool = { if case .locked = vm.lockState { return true } else { return false } }()
        return Button { Task { await vm.capture() } } label: {
            ZStack {
                Circle().strokeBorder(Color.white, lineWidth: 5).frame(width: 84, height: 84)
                    .scaleEffect(locked ? 1.08 : 1)
                Circle().fill(vm.guidanceIsGood ? Theme.leaf : Color.white).frame(width: 68, height: 68)
                    .scaleEffect(vm.phase == .capturing ? 0.8 : 1)
            }
            .animation(Motion.bouncy, value: locked)
            .animation(Motion.snappy, value: vm.phase)
            .animation(Motion.snappy, value: vm.guidanceIsGood)
        }
        .pressable()
        .disabled(vm.phase != .live || vm.cameraDenied)
        .accessibilityLabel("Capture")
        .accessibilityHint("Takes a photo and identifies the plant")
        .accessibilityIdentifier("scan.shutter")
    }

    private var torchButton: some View {
        let on = vm.torchIsOn
        let caption: String = { switch vm.torchMode { case .auto: return on ? "Auto · on" : "Auto"; case .on: return "On"; case .off: return "Off" } }()
        return Button { vm.cycleTorch() } label: {
            VStack(spacing: 4) {
                Image(systemName: on ? "flashlight.on.fill" : "flashlight.off.fill").font(.title2)
                    .contentTransition(.symbolEffect(.replace))
                if !compact { Text(caption).font(.caption2) }
            }
            .frame(minWidth: 64, minHeight: 64)
            .background(on ? Theme.leaf.opacity(0.9) : Color.black.opacity(0.45), in: RoundedRectangle(cornerRadius: 14))
            .foregroundStyle(.white)
            .animation(Motion.snappy, value: on)
        }
        .pressable()
        .accessibilityLabel("Flashlight, \(caption)")
        .accessibilityHint("Automatic in the dark. Tap to force on, off, or back to automatic")
    }
}

private struct SamplePhotoButton: View {
    let vm: ScanViewModel
    var body: some View {
        Button("Use sample photo") {
            if let url = Bundle.main.url(forResource: "sample_leaf", withExtension: "jpg"),
               let data = try? Data(contentsOf: url),
               let cg = ImageLoading.cgImage(fromJPEGData: data, maxDimension: 1200) {
                Task { await vm.analyzePicked(cg, overrideQuality: .perfect) }
            }
        }
        .buttonStyle(.bordered)
        .tint(.white)
        .accessibilityIdentifier("scan.samplePhoto")
    }
}

/// Quick white flash when the shutter fires.
private struct CaptureFlash: View {
    let trigger: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flash = false
    var body: some View {
        Color.white
            .opacity(flash ? 0.7 : 0)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onChange(of: trigger) { _, firing in
                guard firing, !reduceMotion else { return }
                flash = true
                withAnimation(.easeOut(duration: 0.35)) { flash = false }
            }
    }
}

private struct AnalyzingOverlay: View {
    let capturing: Bool
    let hint: String?
    @State private var pulse = false
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 34))
                .foregroundStyle(Theme.leaf)
                .symbolEffect(.pulse.byLayer, options: .repeating, isActive: true)
                .rotationEffect(.degrees(pulse ? 8 : -8))
                .onAppear { withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true } }
            Text(capturing ? "Capturing…" : "Identifying…").font(.headline).foregroundStyle(.white)
            if let hint {
                Text(hint).font(.footnote).foregroundStyle(.white.opacity(0.85)).multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .background(Color.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 20))
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
