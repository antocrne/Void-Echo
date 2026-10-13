import SwiftUI

@main
struct VoidEchoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var settings = AppSettings.shared
    @State private var model = AppModel.shared
    @State private var history = HistoryStore.shared
    @State private var devices = CaptureDevices.shared

    var body: some Scene {
        // One window, one meeting at a time.
        Window("Void Echo", id: "main") {
            MainWindowView()
                .environment(settings)
                .environment(model)
                .environment(history)
                .environment(devices)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1000, height: 700)
        .commands { EchoCommands(model: model) }

        Settings {
            SettingsView()
                .environment(settings)
                .environment(devices)
        }
    }
}
