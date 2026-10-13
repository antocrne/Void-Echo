import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var keyMonitor: Any?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // One window; no "Show Tab Bar" menu items.
        NSWindow.allowsAutomaticWindowTabbing = false
        MainActor.assumeIsolated { AppSettings.shared.applyAppearance() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        MainActor.assumeIsolated { DebugProbe.start() }
        #endif
        // ⌘D, ⌘E and ⌘W in a meeting reach Void Echo before the page: the meeting's web view
        // would otherwise see them first, and ⌘W would close the window instead of leaving.
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let key = event.charactersIgnoringModifiers?.lowercased()
            let commandOnly = event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command
            guard commandOnly, let key else { return event }
            return MainActor.assumeIsolated { Self.handleMeetingShortcut(key) } ? nil : event
        }
    }

    /// ⌘ + `key`: true when it was a meeting shortcut, handled.
    @MainActor private static func handleMeetingShortcut(_ key: String) -> Bool {
        let model = AppModel.shared
        guard let meeting = model.meeting, NSApp.keyWindow?.isMainVoidEchoWindow == true else { return false }
        switch key {
        case "d": meeting.toggleMicrophone()
        case "e": meeting.toggleCamera()
        case "w": Task { await model.leaveMeeting() }
        default: return false
        }
        return true
    }

    /// Quitting during a meeting: leave it properly first (the others see you go at once).
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        MainActor.assumeIsolated {
            guard AppModel.shared.inMeeting else { return .terminateNow }
            Task {
                await AppModel.shared.leaveMeeting()
                sender.reply(toApplicationShouldTerminate: true)
            }
            return .terminateLater
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

extension NSWindow {
    static let mainAutosaveName = "VoidEchoMainWindow"

    var isMainVoidEchoWindow: Bool { frameAutosaveName == Self.mainAutosaveName }
}
