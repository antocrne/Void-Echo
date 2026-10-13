@preconcurrency import AVFoundation
import Observation

/// The pre-join screen's camera preview and microphone level, on the devices chosen there. The
/// camera and the microphone each have their own capture session, so turning one off really
/// releases it (the camera's green light goes out). Everything stops before the meeting opens:
/// Jitsi then opens the devices itself.
@MainActor @Observable
final class PreviewSession {
    /// 0…1, smoothed: the microphone's level, for the meter under the preview.
    private(set) var level: Double = 0
    /// The camera delivers images (false while it starts, or when it can't be opened).
    private(set) var cameraRunning = false

    @ObservationIgnored let videoSession = AVCaptureSession()
    @ObservationIgnored private let audioSession = AVCaptureSession()
    @ObservationIgnored private let queue = DispatchQueue(label: "app.void.echo.preview")
    @ObservationIgnored private let meter = LevelMeter()
    @ObservationIgnored private var cameraID: String?
    @ObservationIgnored private var microphoneID: String?

    init() {
        meter.onLevel = { [weak self] value in
            Task { @MainActor in
                guard let self else { return }
                // Fast up, slow down: reads like a VU meter.
                self.level = value > self.level ? value : self.level * 0.75 + value * 0.25
            }
        }
    }

    /// Shows `id`'s image, or nothing (nil: camera off).
    func setCamera(_ id: String?) {
        guard id != cameraID || (id != nil && !videoSession.isRunning) else { return }
        cameraID = id
        cameraRunning = false
        let session = videoSession
        queue.async { [weak self] in
            session.stopRunning()
            session.beginConfiguration()
            session.inputs.forEach(session.removeInput)
            var running = false
            if let id, let device = CaptureDevices.device(id: id), let input = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(input) {
                session.addInput(input)
                session.sessionPreset = session.canSetSessionPreset(.high) ? .high : session.sessionPreset
                session.commitConfiguration()
                session.startRunning()
                running = session.isRunning
            } else {
                session.commitConfiguration()
            }
            Task { @MainActor in self?.cameraRunning = running }
        }
    }

    /// Measures `id`'s level, or nothing (nil: microphone off).
    func setMicrophone(_ id: String?) {
        guard id != microphoneID || (id != nil && !audioSession.isRunning) else { return }
        microphoneID = id
        level = 0
        let session = audioSession, meter = meter, queue = queue
        queue.async {
            session.stopRunning()
            session.beginConfiguration()
            session.inputs.forEach(session.removeInput)
            if session.outputs.isEmpty {
                let output = AVCaptureAudioDataOutput()
                output.setSampleBufferDelegate(meter, queue: queue)
                if session.canAddOutput(output) { session.addOutput(output) }
            }
            if let id, let device = CaptureDevices.device(id: id), let input = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(input) {
                session.addInput(input)
                session.commitConfiguration()
                session.startRunning()
            } else {
                session.commitConfiguration()
            }
        }
    }

    /// Releases both devices. Waits until they are released, so Jitsi finds them free.
    func stop() async {
        cameraID = nil
        microphoneID = nil
        cameraRunning = false
        level = 0
        let video = videoSession, audio = audioSession
        await withCheckedContinuation { continuation in
            queue.async {
                video.stopRunning()
                audio.stopRunning()
                continuation.resume()
            }
        }
    }
}

/// Reads the average power the capture connection already computes, about 15 times a second.
private final class LevelMeter: NSObject, AVCaptureAudioDataOutputSampleBufferDelegate, @unchecked Sendable {
    var onLevel: ((Double) -> Void)?
    private var last = Date.distantPast

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(last) > 1.0 / 15 else { return }
        last = now
        let channels = connection.audioChannels
        guard !channels.isEmpty else { return }
        let decibels = channels.map { Double($0.averagePowerLevel) }.max() ?? -160
        // -50 dB (silence in a quiet room) … 0 dB.
        onLevel?(min(1, max(0, (decibels + 50) / 50)))
    }
}
