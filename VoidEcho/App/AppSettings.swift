import AppKit
import Observation

enum ThemeChoice: String, CaseIterable, Identifiable {
    case dark, light, system
    var id: String { rawValue }
    var label: String {
        switch self {
        case .dark: "Sombre"
        case .light: "Clair"
        case .system: "Système"
        }
    }
}

/// User preferences, persisted in UserDefaults. Same keys and defaults as Void, Void Calendar and
/// Void Notes for what they share (theme, accent, tint), but in Void Echo's own domain.
@MainActor @Observable
final class AppSettings {
    static let shared = AppSettings()
    @ObservationIgnored private let defaults = UserDefaults.standard

    var theme: ThemeChoice { didSet { defaults.set(theme.rawValue, forKey: "theme"); applyAppearance() } }
    var accent: AccentChoice { didSet { defaults.set(accent.rawValue, forKey: "accent") } }
    /// Tint of the window's frame (see ChromeTint.swift); same keys and defaults as Void.
    var chromeTint: ChromeTint { didSet { defaults.set(chromeTint.rawValue, forKey: "chromeTint") } }
    var chromeTintIntensity: Double { didSet { defaults.set(chromeTintIntensity, forKey: "chromeTintIntensity") } }
    var chromeTintGradient: Bool { didSet { defaults.set(chromeTintGradient, forKey: "chromeTintGradient") } }

    /// Réglages → Serveur Jitsi, as typed. Empty: the default server (`JitsiServer.defaultAddress`).
    var serverAddress: String { didSet { defaults.set(serverAddress, forKey: "serverAddress") } }
    /// Name shown to the other participants; empty: the Mac user's full name.
    var displayName: String { didSet { defaults.set(displayName, forKey: "displayName") } }
    /// AVCaptureDevice unique IDs; nil: the system's default device.
    var cameraID: String? { didSet { defaults.set(cameraID, forKey: "cameraID") } }
    var microphoneID: String? { didSet { defaults.set(microphoneID, forKey: "microphoneID") } }
    /// Enter meetings with the camera / the microphone off.
    var startWithCameraOff: Bool { didSet { defaults.set(startWithCameraOff, forKey: "startWithCameraOff") } }
    var startWithMicrophoneOff: Bool { didSet { defaults.set(startWithMicrophoneOff, forKey: "startWithMicrophoneOff") } }

    private init() {
        let d = UserDefaults.standard
        theme = ThemeChoice(rawValue: d.string(forKey: "theme") ?? "") ?? .dark
        accent = AccentChoice(rawValue: d.string(forKey: "accent") ?? "") ?? .violet
        chromeTint = ChromeTint(rawValue: d.string(forKey: "chromeTint") ?? "") ?? .none
        chromeTintIntensity = d.object(forKey: "chromeTintIntensity") as? Double ?? ChromeLook.amountRange.upperBound
        chromeTintGradient = d.object(forKey: "chromeTintGradient") as? Bool ?? true
        serverAddress = d.string(forKey: "serverAddress") ?? ""
        displayName = d.string(forKey: "displayName") ?? ""
        cameraID = d.string(forKey: "cameraID")
        microphoneID = d.string(forKey: "microphoneID")
        startWithCameraOff = d.bool(forKey: "startWithCameraOff")
        startWithMicrophoneOff = d.bool(forKey: "startWithMicrophoneOff")
    }

    /// The server new meetings and room names go to. An address that can't be read falls back to
    /// the default server (Réglages says so under the field).
    var server: JitsiServer {
        serverAddress.isEmpty ? .default : JitsiServer(address: serverAddress) ?? .default
    }

    /// The name to show: the one chosen in Réglages, else the Mac user's.
    var effectiveDisplayName: String {
        let name = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? NSFullUserName() : name
    }

    var chromeLook: ChromeLook {
        let range = ChromeLook.amountRange
        return ChromeLook(tint: chromeTint,
                          amount: min(range.upperBound, max(range.lowerBound, chromeTintIntensity)), gradient: chromeTintGradient)
    }

    func applyAppearance() {
        switch theme {
        case .dark: NSApp.appearance = NSAppearance(named: .darkAqua)
        case .light: NSApp.appearance = NSAppearance(named: .aqua)
        case .system: NSApp.appearance = nil
        }
    }
}
