import SwiftUI

/// The single window: home, pre-join screen or meeting, on the window's frame color (Void's
/// chrome, tinted or not). In a meeting, Jitsi takes the whole window below the title bar.
struct MainWindowView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(spacing: 0) {
            // The window's own title bar, drawn here as in Void: no system toolbar (and none of
            // its glass capsules). Empty at home; the room and its actions in a meeting.
            TopBar()
            ZStack {
                switch model.screen {
                case .home:
                    HomeView()
                        .transition(.opacity)
                case .prejoin(let room):
                    PrejoinView(room: room)
                        .id(room.id)
                        .transition(.opacity)
                case .meeting:
                    if let meeting = model.meeting {
                        MeetingView(session: meeting)
                    }
                }
            }
            .animation(Theme.quick, value: model.screen)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.container, edges: .top)
        .frame(minWidth: 720, minHeight: 540)
        .foregroundStyle(Theme.primaryText)
        .tint(Theme.accent)
        .background(TrafficLightsAlignment(centerY: TopBar.height / 2))
        .background(WindowAccessor(configure: configure))
        .onChange(of: settings.chromeLook) { mainWindow?.backgroundColor = Theme.chromeNS }
    }

    private var mainWindow: NSWindow? { NSApp.windows.first { $0.isMainVoidEchoWindow } }

    private func configure(_ window: NSWindow) {
        window.toolbar = nil
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        // The content goes up to the top edge: the title bar is TopBar, the window's buttons sit
        // in it (TrafficLightsAlignment), and the window moves from its empty places.
        window.styleMask.insert(.fullSizeContentView)
        window.tabbingMode = .disallowed
        window.backgroundColor = Theme.chromeNS
        ChromeBackdrop.install(in: window, settings: settings)
        window.setFrameAutosaveName(NSWindow.mainAutosaveName)
    }
}

/// The top of the window, on the frame's color: room for the window's buttons, then, in a
/// meeting, the room's name and its three actions. Its empty places move the window.
private struct TopBar: View {
    static let height: CGFloat = 40
    @Environment(AppModel.self) private var model

    var body: some View {
        HStack(spacing: 2) {
            // The window's buttons.
            Color.clear.frame(width: 72)
            Spacer(minLength: 8)
            if let meeting = model.meeting {
                MeetingBarActions(session: meeting)
            }
        }
        .padding(.trailing, 8)
        .frame(height: Self.height)
        .overlay {
            if let meeting = model.meeting {
                MeetingBarTitle(session: meeting)
                    .allowsHitTesting(false)
                    .padding(.horizontal, 130)
            }
        }
        .background(TitleBarDragArea())
    }
}
