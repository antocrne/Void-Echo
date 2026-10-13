import SwiftUI

/// Home: two buttons — "Nouvelle réunion", "Rejoindre" — and the recent meetings.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 32)
            VStack(spacing: 10) {
                EchoLogo(size: 40)
                Text("Void Echo")
                    .font(.system(size: 22, weight: .semibold))
                Text("Une réunion vidéo, un lien à partager. Sans compte.")
                    .foregroundStyle(Theme.secondaryText)
            }
            .padding(.bottom, 28)

            HStack(spacing: 10) {
                Button { model.newMeeting() } label: {
                    Label("Nouvelle réunion", systemImage: "video.fill").frame(minWidth: 150)
                }
                .voidPrimaryButton()
                .keyboardShortcut(.defaultAction)
                Button { withAnimation(Theme.quick) { model.showsJoinField.toggle() } } label: {
                    Label("Rejoindre", systemImage: "arrow.right").frame(minWidth: 150)
                }
                .voidSecondaryButton()
            }
            .controlSize(.large)

            if model.showsJoinField {
                JoinField()
                    .padding(.top, 14)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            RecentMeetings()
                .padding(.top, 40)
            Spacer(minLength: 24)
        }
        .frame(maxWidth: 480)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
    }
}

/// "Rejoindre": a link (of any Jitsi server) or a room name of the configured server. A link
/// already copied is proposed at once.
private struct JoinField: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @State private var text = ""
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField("Lien de la réunion ou nom de la salle", text: $text)
                    .voidTextField()
                    .focused($focused)
                    .onSubmit(join)
                    .onChange(of: text) { error = nil }
                Button("Rejoindre", action: join)
                    .voidPrimaryButton()
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .controlSize(.large)
            Text(error ?? "Un nom seul ouvre la salle sur \(settings.server.displayName).")
                .font(.caption)
                .foregroundStyle(error == nil ? Theme.secondaryText : Theme.danger)
        }
        .onAppear {
            if text.isEmpty, let copied = NSPasteboard.general.string(forType: .string),
               copied.count < 300, copied.lowercased().hasPrefix("https://"),
               case .success = MeetingLinkParser.parse(copied, defaultServer: settings.server) {
                text = copied.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            focused = true
        }
        .onExitCommand { withAnimation(Theme.quick) { model.showsJoinField = false } }
    }

    private func join() {
        error = model.join(text)
    }
}
