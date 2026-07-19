import AVFoundation
import os

final class CameraManager: NSObject, ObservableObject {
    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "cam", qos: .userInitiated)
    private let videoOut = AVCaptureVideoDataOutput()
    private var jpegOut: AVCapturePhotoOutput?

    var onFrame: ((CMSampleBuffer) -> Void)?
    @Published var running = false

    func start() {
        queue.async { [weak self] in
            guard let self, !self.session.isRunning else { return }
            self.configure()
            self.session.startRunning()
            Task { @MainActor in self.running = true }
        }
    }

    func stop() {
        queue.async { [weak self] in
            self?.session.stopRunning()
            Task { @MainActor in self?.running = false }
        }
    }

    private func configure() {
        session.beginConfiguration()
        session.sessionPreset = .hd1280x720  // 720p for streaming

        guard let cam = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: cam),
              session.canAddInput(input) else {
            session.commitConfiguration(); return
        }
        session.addInput(input)
        try? cam.lockForConfiguration()
        cam.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        cam.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
        cam.unlockForConfiguration()

        videoOut.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOut.alwaysDiscardsLateVideoFrames = true
        videoOut.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(videoOut) { session.addOutput(videoOut) }

        session.commitConfiguration()
    }
}

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_: AVCaptureOutput, didOutput buf: CMSampleBuffer, from: AVCaptureConnection) {
        onFrame?(buf)
    }
}
