import AVFoundation
import SwiftUI

/// Before entering: the name shown to the others, the camera and the microphone (with their
/// preview and level), each of which can be turned off; the room's link, to copy at once.
/// Defaults come from Réglages; choices made here are for this meeting only.
struct PrejoinView: View {
    let room: MeetingRoom
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(CaptureDevices.self) private var devices
    @State private var preview = PreviewSession()
    @State private var name = ""
    @State private var cameraID: String?
    @State private var microphoneID: String?
    @State private var cameraOn = true
    @State private var microphoneOn = true
    @State private var denied: [MediaKind] = []
    @State private var entering = false

    var body: some View {
        HStack(alignment: .center, spacing: 32) {
            VStack(spacing: 12) {
                previewArea
                LevelBar(level: microphoneOn && !denied.contains(.microphone) ? preview.level : 0, active: microphoneOn)
            }
            .frame(width: 420)

            VStack(alignment: .leading, spacing: 16) {
                header
                VStack(alignment: .leading, spacing: 10) {
                    field("Votre nom") {
                        TextField(NSFullUserName(), text: $name)
                            .voidTextField()
                            .onSubmit(enter)
                    }
                    field("Caméra") {
                        devicePicker(devices.cameras, selection: $cameraID, empty: "Aucune caméra")
                    }
                    field("Micro") {
                        devicePicker(devices.microphones, selection: $microphoneID, empty: "Aucun micro")
                    }
                }
                if !denied.isEmpty {
                    deniedNotice
                }
                HStack(spacing: 8) {
                    Button("Annuler") { leave() }
                        .voidSecondaryButton()
                        .keyboardShortcut(.cancelAction)
                    Button(action: enter) {
                        Text(entering ? "Connexion…" : "Entrer dans la réunion").frame(minWidth: 160)
                    }
                    .voidPrimaryButton()
                    .keyboardShortcut(.defaultAction)
                    .disabled(entering)
                }
                .controlSize(.large)
                .padding(.top, 4)
            }
            .frame(width: 300)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { await start() }
        .onChange(of: cameraID) { updateCamera() }
        .onChange(of: cameraOn) { Task { await ensureAccess(.camera); updateCamera() } }
        .onChange(of: microphoneID) { updateMicrophone() }
        .onChange(of: microphoneOn) { Task { await ensureAccess(.microphone); updateMicrophone() } }
        .onDisappear { Task { await preview.stop() } }
    }

    // MARK: Parts

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(room.displayName)
                .font(.system(size: 18, weight: .semibold))
                .lineLimit(2)
            HStack(spacing: 6) {
                Text(room.link)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
                let copied = model.copiedLink == room.link
                Button { model.copyLink(room) } label: {
                    Label(copied ? "Copié" : "Copier le lien", systemImage: copied ? "checkmark" : "link")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(copied ? Theme.onAccent : Theme.accent)
                        .padding(.horizontal, 7)
                        .frame(height: 20)
                        .background(Capsule().fill(copied ? Theme.accentFill : Theme.accentSoft))
                        .fixedSize()
                }
                .buttonStyle(.plain)
                .help("Copier le lien à envoyer aux participants")
            }
        }
    }

    private var previewArea: some View {
        ZStack {
            Theme.videoBackground
            if cameraOn && !denied.contains(.camera) && cameraID != nil {
                CameraPreview(session: preview.videoSession)
                    .opacity(preview.cameraRunning ? 1 : 0)
                if !preview.cameraRunning {
                    ProgressView().controlSize(.small).tint(Theme.onVideo)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 26, weight: .light))
                    Text(cameraMessage)
                        .font(.system(size: 12))
                }
                .foregroundStyle(Theme.onVideo.opacity(0.7))
            }
        }
        .aspectRatio(16 / 10, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.stroke))
        .overlay(alignment: .bottom) {
            HStack(spacing: 12) {
                DeviceToggle(on: $microphoneOn, onSymbol: "mic.fill", offSymbol: "mic.slash.fill",
                             label: microphoneOn ? "Couper le micro" : "Activer le micro")
                DeviceToggle(on: $cameraOn, onSymbol: "video.fill", offSymbol: "video.slash.fill",
                             label: cameraOn ? "Couper la caméra" : "Activer la caméra")
            }
            .padding(.bottom, 14)
        }
    }

    private var cameraMessage: String {
        if !cameraOn { return "Caméra coupée" }
        if denied.contains(.camera) { return "Pas d'accès à la caméra" }
        return "Aucune caméra"
    }

    private var deniedNotice: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(MediaAccess.deniedMessage(denied), systemImage: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.danger)
            Text("Autorisez-le dans Réglages Système → Confidentialité et sécurité. Vous pouvez aussi entrer sans.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Button("Ouvrir Réglages Système") { MediaAccess.openSystemSettings(denied[0]) }
                .voidSecondaryButton()
        }
    }

    private func field<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.secondaryText)
            content()
        }
    }

    private func devicePicker(_ list: [CaptureDevice], selection: Binding<String?>, empty: String) -> some View {
        Picker(selection: selection) {
            if list.isEmpty { Text(empty).tag(String?.none) }
            ForEach(list) { Text($0.name).tag(Optional($0.id)) }
        } label: {
            EmptyView()
        }
        .labelsHidden()
        .pickerStyle(.menu)
        .disabled(list.isEmpty)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Behavior

    private func start() async {
        name = settings.displayName
        cameraOn = !settings.startWithCameraOff
        microphoneOn = !settings.startWithMicrophoneOff
        cameraID = devices.resolve(.camera, id: settings.cameraID)?.id
        microphoneID = devices.resolve(.microphone, id: settings.microphoneID)?.id
        // macOS asks once, here, rather than in the middle of the meeting.
        if cameraOn { await ensureAccess(.camera) }
        if microphoneOn { await ensureAccess(.microphone) }
        updateCamera()
        updateMicrophone()
    }

    private func ensureAccess(_ kind: MediaKind) async {
        let wanted = kind == .camera ? cameraOn : microphoneOn
        guard wanted else { return }
        let granted = await MediaAccess.request(kind)
        if granted { denied.removeAll { $0 == kind } } else if !denied.contains(kind) { denied.append(kind) }
    }

    private func updateCamera() {
        preview.setCamera(cameraOn && MediaAccess.status(.camera) == .granted ? cameraID : nil)
    }

    private func updateMicrophone() {
        preview.setMicrophone(microphoneOn && MediaAccess.status(.microphone) == .granted ? microphoneID : nil)
    }

    private func enter() {
        guard !entering else { return }
        entering = true
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let options = JoinOptions(
            displayName: trimmed.isEmpty ? settings.effectiveDisplayName : trimmed,
            cameraName: devices.cameras.first { $0.id == cameraID }?.name,
            microphoneName: devices.microphones.first { $0.id == microphoneID }?.name,
            cameraOff: !cameraOn,
            microphoneOff: !microphoneOn)
        Task {
            // Jitsi opens the devices itself: the preview lets go of them first.
            await preview.stop()
            model.enter(room, options: options)
        }
    }

    private func leave() {
        Task { await preview.stop() }
        model.cancelPrejoin()
    }
}

/// A round button over the preview: white when the device is on, red when it's off.
private struct DeviceToggle: View {
    @Binding var on: Bool
    let onSymbol: String
    let offSymbol: String
    let label: String

    var body: some View {
        Button { on.toggle() } label: {
            Image(systemName: on ? onSymbol : offSymbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.onVideo)
                .frame(width: 40, height: 40)
                .background(Circle().fill(on ? Theme.onVideoControl : Theme.mutedControl))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

/// The microphone's level, in the accent color.
private struct LevelBar: View {
    let level: Double
    let active: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: active ? "mic" : "mic.slash")
                .font(.system(size: 11))
                .foregroundStyle(Theme.secondaryText)
                .frame(width: 14)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.hover)
                    Capsule().fill(Theme.accent)
                        .frame(width: max(0, geo.size.width * level))
                        .animation(.linear(duration: 0.08), value: level)
                }
            }
            .frame(height: 4)
        }
        .accessibilityElement()
        .accessibilityLabel("Niveau du micro")
        .accessibilityValue(Text(level, format: .percent.precision(.fractionLength(0))))
    }
}

/// The camera's image, mirrored as in a mirror (as Jitsi shows it to you).
private struct CameraPreview: NSViewRepresentable {
    let session: AVCaptureSession

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        return view
    }

    func updateNSView(_ view: PreviewView, context: Context) {}

    final class PreviewView: NSView {
        let previewLayer = AVCaptureVideoPreviewLayer()

        override init(frame: NSRect) {
            super.init(frame: frame)
            wantsLayer = true
            previewLayer.videoGravity = .resizeAspectFill
            layer = previewLayer
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError() }

        override func layout() {
            super.layout()
            if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
            }
        }
    }
}
