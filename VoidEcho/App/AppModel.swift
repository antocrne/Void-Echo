import AppKit
import Observation

/// What the window shows, and the one meeting that may be open: home → pre-join screen → meeting
/// → home. One meeting at a time: a new one can only start once the current one is left.
@MainActor @Observable
final class AppModel {
    static let shared = AppModel()

    enum Screen: Equatable {
        case home
        case prejoin(MeetingRoom)
        case meeting
    }

    private(set) var screen: Screen = .home
    private(set) var meeting: MeetingSession?
    /// "Rejoindre" opened on the home screen, its field focused (⌘J, or the button).
    var showsJoinField = false
    /// A link was just copied: the "Lien copié" confirmation shows for a moment.
    private(set) var copiedLink: String?

    private var settings: AppSettings { .shared }
    private var history: HistoryStore { .shared }

    var inMeeting: Bool { meeting != nil }

    // MARK: Home

    /// A new room on the configured server, with a name nobody can guess.
    func newMeeting() {
        guard !inMeeting else { return }
        screen = .prejoin(MeetingRoom(server: settings.server, name: RoomNameGenerator.make()))
    }

    /// The text of the "Rejoindre" field: a link or a room name. Returns what's wrong with it.
    func join(_ input: String) -> String? {
        guard !inMeeting else { return nil }
        switch MeetingLinkParser.parse(input, defaultServer: settings.server) {
        case .success(let room):
            showsJoinField = false
            screen = .prejoin(room)
            return nil
        case .failure(let failure):
            return MeetingLinkParser.message(for: failure)
        }
    }

    func rejoin(_ entry: HistoryEntry) {
        guard !inMeeting else { return }
        screen = .prejoin(entry.room)
    }

    func cancelPrejoin() {
        screen = .home
    }

    // MARK: Meeting

    func enter(_ room: MeetingRoom, options: JoinOptions) {
        guard !inMeeting else { return }
        let session = MeetingSession(room: room, options: options)
        session.onEnded = { [weak self, weak session] in
            guard let self, let session, self.meeting === session else { return }
            self.end()
        }
        meeting = session
        history.record(room)
        screen = .meeting
    }

    /// ⌘W in a meeting: leave properly, then back home.
    func leaveMeeting() async {
        guard let session = meeting else { return }
        await session.leave()
        if meeting === session { end() }
    }

    /// Jitsi left by itself (hang-up button, end of the meeting).
    private func end() {
        meeting?.close()
        meeting = nil
        screen = .home
    }

    /// Opens the room in the default browser (screen sharing with the sound, a browser extension…)
    /// and leaves it here, so as not to be twice in the meeting.
    func openInBrowser() async {
        guard let room = meeting?.room else { return }
        await leaveMeeting()
        NSWorkspace.shared.open(room.url)
    }

    // MARK: Link

    func copyLink(_ room: MeetingRoom) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(room.link, forType: .string)
        copiedLink = room.link
        Task {
            try? await Task.sleep(for: .seconds(2))
            if copiedLink == room.link { copiedLink = nil }
        }
    }
}
