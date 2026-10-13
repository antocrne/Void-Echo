import AppKit
import AVFoundation
import Observation

/// The camera or the microphone, as macOS grants them to Void Echo (Réglages Système →
/// Confidentialité et sécurité). Without it, neither the preview nor Jitsi gets any image or sound,
/// whatever the page asks: Void Echo then says so and offers the right panel.
enum MediaKind: String, CaseIterable, Identifiable {
    case camera, microphone
    var id: String { rawValue }

    var mediaType: AVMediaType { self == .camera ? .video : .audio }

    var label: String { self == .camera ? "caméra" : "micro" }

    /// The privacy panel of Réglages Système for this device.
    var settingsURL: URL {
        URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_\(self == .camera ? "Camera" : "Microphone")")!
    }
}

enum MediaAccess {
    enum Status { case granted, notDetermined, denied }

    static func status(_ kind: MediaKind) -> Status {
        switch AVCaptureDevice.authorizationStatus(for: kind.mediaType) {
        case .authorized: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    /// Asks macOS the first time; afterwards answers at once with the user's choice.
    static func request(_ kind: MediaKind) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: kind.mediaType) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: kind.mediaType)
        default: false
        }
    }

    @MainActor static func openSystemSettings(_ kind: MediaKind) {
        NSWorkspace.shared.open(kind.settingsURL)
    }

    /// "Void Echo n'a pas accès à la caméra."
    static func deniedMessage(_ kinds: [MediaKind]) -> String {
        switch kinds.count {
        case 0: ""
        case 1: "Void Echo n'a pas accès \(kinds[0] == .camera ? "à la caméra" : "au micro")."
        default: "Void Echo n'a accès ni à la caméra ni au micro."
        }
    }

    static let deniedExplanation = "Autorisez-le dans Réglages Système → Confidentialité et sécurité, puis revenez ici : la réunion fonctionne sans, mais les autres ne vous verront ou ne vous entendront pas."
}

/// A camera or a microphone, as listed by macOS.
struct CaptureDevice: Identifiable, Hashable {
    let id: String
    let name: String
}

/// The cameras and microphones connected to the Mac, kept up to date as they come and go.
@MainActor @Observable
final class CaptureDevices {
    static let shared = CaptureDevices()

    private(set) var cameras: [CaptureDevice] = []
    private(set) var microphones: [CaptureDevice] = []
    @ObservationIgnored private var observers: [NSObjectProtocol] = []

    private init() {
        reload()
        for name in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reload() }
            })
        }
    }

    func reload() {
        cameras = Self.discover(.camera).map { CaptureDevice(id: $0.uniqueID, name: $0.localizedName) }
        microphones = Self.discover(.microphone).map { CaptureDevice(id: $0.uniqueID, name: $0.localizedName) }
    }

    /// The device chosen (by its ID) if it is still connected, else the system's default.
    func resolve(_ kind: MediaKind, id: String?) -> CaptureDevice? {
        let list = kind == .camera ? cameras : microphones
        if let id, let device = list.first(where: { $0.id == id }) { return device }
        guard let fallback = AVCaptureDevice.default(for: kind.mediaType) else { return list.first }
        return CaptureDevice(id: fallback.uniqueID, name: fallback.localizedName)
    }

    nonisolated static func discover(_ kind: MediaKind) -> [AVCaptureDevice] {
        let types: [AVCaptureDevice.DeviceType] = kind == .camera
            ? [.builtInWideAngleCamera, .external, .continuityCamera]
            : [.microphone, .external]
        return AVCaptureDevice.DiscoverySession(deviceTypes: types, mediaType: kind.mediaType, position: .unspecified).devices
    }

    nonisolated static func device(id: String) -> AVCaptureDevice? {
        AVCaptureDevice(uniqueID: id)
    }
}
