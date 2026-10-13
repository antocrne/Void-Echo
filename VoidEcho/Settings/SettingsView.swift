import SwiftUI

/// Réglages (⌘,): the server, how to enter meetings, the appearance. Every change applies at once
/// (to the next meeting for the server and the devices).
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(CaptureDevices.self) private var devices

    var body: some View {
        @Bindable var settings = settings
        Form {
            ServerSection()

            Section("En entrant dans une réunion") {
                LabeledContent("Nom affiché") {
                    TextField("", text: $settings.displayName, prompt: Text(NSFullUserName()))
                        .voidTextField()
                        .frame(width: 240)
                }
                Picker("Caméra", selection: $settings.cameraID) {
                    Text("Celle de macOS par défaut").tag(String?.none)
                    ForEach(devices.cameras) { Text($0.name).tag(Optional($0.id)) }
                    missingDevice(settings.cameraID, in: devices.cameras)
                }
                Picker("Micro", selection: $settings.microphoneID) {
                    Text("Celui de macOS par défaut").tag(String?.none)
                    ForEach(devices.microphones) { Text($0.name).tag(Optional($0.id)) }
                    missingDevice(settings.microphoneID, in: devices.microphones)
                }
                Toggle("Caméra coupée à l'entrée", isOn: $settings.startWithCameraOff)
                Toggle("Micro coupé à l'entrée", isOn: $settings.startWithMicrophoneOff)
            }

            Section("Apparence") {
                Picker("Thème", selection: $settings.theme) {
                    ForEach(ThemeChoice.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                LabeledContent("Couleur") { AccentPicker() }
                LabeledContent("Teinte de la fenêtre") { ChromeTintPicker() }
                ChromeTintOptions()
            }

            PermissionsSection()
        }
        .formStyle(.grouped)
        .toggleStyle(AccentSwitchStyle())
        .tint(Theme.accent)
        .frame(width: 540)
        .frame(minHeight: 560)
    }

    /// A device chosen earlier but unplugged now: still shown, so the choice isn't lost.
    @ViewBuilder private func missingDevice(_ id: String?, in list: [CaptureDevice]) -> some View {
        if let id, !list.contains(where: { $0.id == id }) {
            Text("Appareil déconnecté").tag(Optional(id))
        }
    }
}

/// The Jitsi server: meet.jit.si until another is typed. Applies to new meetings and to room
/// names typed alone; a meeting's full link keeps its own server.
private struct ServerSection: View {
    @Environment(AppSettings.self) private var settings
    @State private var text = ""

    private var parsed: JitsiServer? { text.isEmpty ? .default : JitsiServer(address: text) }

    var body: some View {
        Section {
            LabeledContent("Serveur Jitsi") {
                HStack(spacing: 6) {
                    TextField("", text: $text, prompt: Text(JitsiServer.defaultAddress))
                        .voidTextField()
                        .frame(width: 240)
                        .onSubmit(apply)
                        .onChange(of: text) { apply() }
                    if !settings.serverAddress.isEmpty {
                        ChromeButton(symbol: "arrow.uturn.backward", help: "Revenir à \(JitsiServer.defaultAddress)") { text = "" }
                    }
                }
            }
            if parsed == nil {
                Text("Adresse non valide : les réunions restent sur \(JitsiServer.defaultAddress) en attendant.")
                    .font(.caption).foregroundStyle(Theme.danger)
            }
        } header: {
            Text("Serveur")
        } footer: {
            Text("Les nouvelles réunions sont créées sur ce serveur : le service public \(JitsiServer.defaultAddress), votre propre serveur Jitsi Meet (« visio.exemple.fr ») ou un espace JaaS (« 8x8.vc/vpaas-magic-cookie-… »). Un lien complet collé dans « Rejoindre » ouvre toujours la réunion sur son propre serveur.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onAppear { text = settings.serverAddress }
    }

    private func apply() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Kept as typed only when it can be read; "meet.jit.si" itself is the default.
        if trimmed.isEmpty || JitsiServer(address: trimmed) == .default {
            settings.serverAddress = ""
        } else if JitsiServer(address: trimmed) != nil {
            settings.serverAddress = trimmed
        }
    }
}

/// What macOS lets Void Echo use, with a way to change it.
private struct PermissionsSection: View {
    @State private var statuses: [MediaKind: MediaAccess.Status] = [:]

    var body: some View {
        Section {
            ForEach(MediaKind.allCases) { kind in
                LabeledContent {
                    switch statuses[kind] ?? .notDetermined {
                    case .granted:
                        Text("Autorisé").foregroundStyle(.secondary)
                    case .notDetermined:
                        Button("Autoriser…") { Task { _ = await MediaAccess.request(kind); refresh() } }
                    case .denied:
                        Button("Ouvrir Réglages Système") { MediaAccess.openSystemSettings(kind) }
                    }
                } label: {
                    Text(kind == .camera ? "Caméra" : "Micro")
                    if statuses[kind] == .denied {
                        Text("Refusé : les autres ne \(kind == .camera ? "vous voient" : "vous entendent") pas.")
                    }
                }
            }
        } header: {
            Text("Autorisations")
        } footer: {
            Text("Le partage d'écran se choisit au moment de partager : macOS montre alors les écrans et fenêtres disponibles.")
                .font(.caption).foregroundStyle(.secondary)
        }
        .onAppear(perform: refresh)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
    }

    private func refresh() {
        statuses = Dictionary(uniqueKeysWithValues: MediaKind.allCases.map { ($0, MediaAccess.status($0)) })
    }
}

/// Five swatches; the choice applies at once everywhere the accent appears.
struct AccentPicker: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        HStack(spacing: 8) {
            ForEach(AccentChoice.allCases) { choice in
                let selected = settings.accent == choice
                Button { withAnimation(Theme.quick) { settings.accent = choice } } label: {
                    Circle()
                        .fill(Theme.swatch(choice))
                        .frame(width: 18, height: 18)
                        .overlay {
                            if selected {
                                Image(systemName: "checkmark").font(.system(size: 9, weight: .heavy)).foregroundStyle(Theme.onAccent)
                            }
                        }
                        .padding(3)
                        .overlay(Circle().strokeBorder(selected ? Theme.swatch(choice) : .clear, lineWidth: 2))
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .help(choice.label)
                .accessibilityLabel(choice.label)
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
            Text(settings.accent.label).foregroundStyle(.secondary).frame(minWidth: 44, alignment: .leading)
        }
    }
}
