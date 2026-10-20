import Foundation
import AVFoundation
import QuartzCore
import CoreGraphics
import ImageIO
import Observation

/// AVCaptureSession wrapper: live frames at about 4 fps on a background queue, plus full-resolution stills.
@Observable
final class CameraService: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCapturePhotoCaptureDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "sentry.camera.session")
    private let videoQueue = DispatchQueue(label: "sentry.camera.video", qos: .userInitiated)
    private let videoOutput = AVCaptureVideoDataOutput()
    private let photoOutput = AVCapturePhotoOutput()
    private var configured = false
    private var lastFrameTime: CFTimeInterval = 0
    var frameInterval: CFTimeInterval = 0.25
    private(set) var isRunning = false
    private(set) var lastError: String?
    private(set) var authorization: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
    private(set) var torchOn = false
    private(set) var torchAvailable = false
    @ObservationIgnored private var device: AVCaptureDevice?

    /// Called on the video queue. Keep it fast or drop frames.
    @ObservationIgnored var onFrame: ((CVPixelBuffer, CGImagePropertyOrientation) -> Void)?
    @ObservationIgnored private var photoContinuation: CheckedContinuation<CGImage, Error>?

    var isAuthorized: Bool { authorization == .authorized }

    func requestAccess() async -> Bool {
        if authorization == .notDetermined {
            let ok = await AVCaptureDevice.requestAccess(for: .video)
            authorization = AVCaptureDevice.authorizationStatus(for: .video)
            return ok
        }
        return isAuthorized
    }

    func start() {
        sessionQueue.async { [self] in
            if !configured { configure() }
            guard configured, !session.isRunning else { return }
            session.startRunning()
            DispatchQueue.main.async { self.isRunning = self.session.isRunning }
        }
    }

    func stop() {
        setTorch(false)
        sessionQueue.async { [self] in
            guard session.isRunning else { return }
            session.stopRunning()
            DispatchQueue.main.async { self.isRunning = false }
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        defer { session.commitConfiguration() }
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device), session.canAddInput(input) else {
            DispatchQueue.main.async { self.lastError = "No back camera available." }
            return
        }
        session.addInput(input)
        self.device = device
        let hasTorch = device.hasTorch && device.isTorchAvailable
        DispatchQueue.main.async { self.torchAvailable = hasTorch }
        do {
            try device.lockForConfiguration()
            Self.applyContinuousFocusAndExposure(device, at: CGPoint(x: 0.5, y: 0.5))
            #if os(iOS)
            if device.isAutoFocusRangeRestrictionSupported { device.autoFocusRangeRestriction = .near }
            if device.isLowLightBoostSupported { device.automaticallyEnablesLowLightBoostWhenAvailable = true }
            #endif
            // Let auto-exposure use up to 1/15 s in deep shade: brighter, less noisy frames for the classifier.
            let fps15 = CMTime(value: 1, timescale: 15)
            if device.activeFormat.videoSupportedFrameRateRanges.contains(where: { $0.maxFrameDuration >= fps15 }) {
                device.activeVideoMaxFrameDuration = fps15
            }
            device.isSubjectAreaChangeMonitoringEnabled = true
            device.unlockForConfiguration()
        } catch { /* focus and exposure defaults are fine */ }
        NotificationCenter.default.addObserver(self, selector: #selector(subjectAreaChanged), name: .AVCaptureDeviceSubjectAreaDidChange, object: device)
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }
        if session.canAddOutput(photoOutput) { session.addOutput(photoOutput) }
        photoOutput.maxPhotoQualityPrioritization = .quality
        for output in [videoOutput as AVCaptureOutput, photoOutput] {
            if let c = output.connection(with: .video) {
                if c.isVideoRotationAngleSupported(90) { c.videoRotationAngle = 90 }  // portrait
            }
        }
        configured = true
    }

    // MARK: Focus and exposure
    /// Continuous focus and exposure, metered around `point` (0...1, capture-device coordinates).
    private static func applyContinuousFocusAndExposure(_ device: AVCaptureDevice, at point: CGPoint) {
        if device.isFocusPointOfInterestSupported { device.focusPointOfInterest = point }
        if device.isFocusModeSupported(.continuousAutoFocus) { device.focusMode = .continuousAutoFocus }
        if device.isExposurePointOfInterestSupported { device.exposurePointOfInterest = point }
        if device.isExposureModeSupported(.continuousAutoExposure) { device.exposureMode = .continuousAutoExposure }
    }

    /// Tap to focus: one-shot focus and exposure on the tapped point (device coordinates from the preview layer).
    /// The camera returns to continuous mode by itself when the scene changes (subject-area monitoring).
    func focus(at devicePoint: CGPoint) {
        sessionQueue.async { [self] in
            guard let device else { return }
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported, device.isFocusModeSupported(.autoFocus) {
                    device.focusPointOfInterest = devicePoint; device.focusMode = .autoFocus
                }
                if device.isExposurePointOfInterestSupported, device.isExposureModeSupported(.autoExpose) {
                    device.exposurePointOfInterest = devicePoint; device.exposureMode = .autoExpose
                }
                device.unlockForConfiguration()
            } catch { }
        }
    }

    @objc private func subjectAreaChanged() {
        sessionQueue.async { [self] in
            guard let device, (try? device.lockForConfiguration()) != nil else { return }
            Self.applyContinuousFocusAndExposure(device, at: CGPoint(x: 0.5, y: 0.5))
            device.unlockForConfiguration()
        }
    }

    // MARK: Torch
    func setTorch(_ on: Bool) {
        sessionQueue.async { [self] in
            guard let device, device.hasTorch else { return }
            do {
                try device.lockForConfiguration()
                if on && device.isTorchAvailable {
                    try device.setTorchModeOn(level: min(AVCaptureDevice.maxAvailableTorchLevel, 0.8))
                } else {
                    device.torchMode = .off
                }
                device.unlockForConfiguration()
                DispatchQueue.main.async { self.torchOn = on && device.isTorchAvailable }
            } catch { }
        }
    }

    // MARK: Live frames
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = CACurrentMediaTime()
        guard now - lastFrameTime >= frameInterval, let pb = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastFrameTime = now
        onFrame?(pb, .up)
    }

    // MARK: Stills
    func capturePhoto() async throws -> CGImage {
        try await withCheckedThrowingContinuation { cont in
            sessionQueue.async { [self] in
                guard session.isRunning else { cont.resume(throwing: CameraError.notRunning); return }
                photoContinuation = cont
                // Let focus and exposure settle (up to 0.4 s) so a shutter tap right after a tap-to-focus or a
                // move is not a blurred or half-exposed frame.
                var waited = 0
                while let d = device, (d.isAdjustingFocus || d.isAdjustingExposure), waited < 8 {
                    Thread.sleep(forTimeInterval: 0.05); waited += 1
                }
                let settings = AVCapturePhotoSettings()
                settings.photoQualityPrioritization = .quality
                photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        let cont = photoContinuation; photoContinuation = nil
        if let error { cont?.resume(throwing: error); return }
        guard let data = photo.fileDataRepresentation(), let image = ImageLoading.cgImage(fromJPEGData: data, maxDimension: 2000) else {
            cont?.resume(throwing: CameraError.noImage); return
        }
        cont?.resume(returning: image)
    }

    enum CameraError: LocalizedError {
        case notRunning, noImage
        var errorDescription: String? {
            switch self { case .notRunning: return "The camera is not running."; case .noImage: return "The photo could not be read." }
        }
    }
}

/// Decodes image data with the orientation baked in, so every downstream step can use `.up`.
enum ImageLoading {
    static func cgImage(fromJPEGData data: Data, maxDimension: Int) -> CGImage? {
        guard let src = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let opts: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                     kCGImageSourceThumbnailMaxPixelSize: maxDimension,
                                     kCGImageSourceCreateThumbnailWithTransform: true]
        return CGImageSourceCreateThumbnailAtIndex(src, 0, opts as CFDictionary)
    }
}
