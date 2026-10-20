import SwiftUI
import AVFoundation

/// AVCaptureVideoPreviewLayer in SwiftUI.
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    /// Tap on the preview: the point is converted to capture-device coordinates (0...1) for focus and exposure.
    var onTap: ((CGPoint) -> Void)? = nil

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let v = PreviewView()
        v.previewLayer.session = session
        v.previewLayer.videoGravity = .resizeAspectFill
        if let c = v.previewLayer.connection, c.isVideoRotationAngleSupported(90) { c.videoRotationAngle = 90 }
        v.isAccessibilityElement = true
        v.accessibilityLabel = "Camera preview"
        v.accessibilityHint = "Double tap to focus on that spot"
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        v.addGestureRecognizer(tap)
        return v
    }

    func updateUIView(_ uiView: PreviewView, context: Context) { context.coordinator.onTap = onTap }
    func makeCoordinator() -> Coordinator { Coordinator(onTap: onTap) }

    final class Coordinator: NSObject {
        var onTap: ((CGPoint) -> Void)?
        init(onTap: ((CGPoint) -> Void)?) { self.onTap = onTap }
        @objc func tapped(_ g: UITapGestureRecognizer) {
            guard let v = g.view as? PreviewView else { return }
            let p = v.previewLayer.captureDevicePointConverted(fromLayerPoint: g.location(in: v))
            onTap?(p)
        }
    }
}
