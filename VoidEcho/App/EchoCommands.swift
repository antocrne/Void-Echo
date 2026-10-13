import SwiftUI

/// The menus: "Nouvelle réunion" and "Rejoindre" in Fichier, and a "Réunion" menu whose items
/// work while a meeting is open. ⌘D, ⌘E and ⌘W are also caught before the page (AppDelegate).
struct EchoCommands: Commands {
    let model: AppModel

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Nouvelle réunion") { model.newMeeting() }
                .keyboardShortcut("n")
                .disabled(model.inMeeting)
            Button("Rejoindre une réunion…") {
                model.cancelPrejoin()
                model.showsJoinField = true
            }
            .keyboardShortcut("j")
            .disabled(model.inMeeting)
        }

        CommandMenu("Réunion") {
            let meeting = model.meeting
            Button(meeting?.audioMuted == true ? "Réactiver le micro" : "Couper le micro") { meeting?.toggleMicrophone() }
                .keyboardShortcut("d")
                .disabled(meeting == nil)
            Button(meeting?.videoMuted == true ? "Réactiver la caméra" : "Couper la caméra") { meeting?.toggleCamera() }
                .keyboardShortcut("e")
                .disabled(meeting == nil)
            Divider()
            Button("Copier le lien de la réunion") { if let room = meeting?.room { model.copyLink(room) } }
                .keyboardShortcut("c", modifiers: [.command, .shift])
                .disabled(meeting == nil)
            Button("Ouvrir dans le navigateur") { Task { await model.openInBrowser() } }
                .disabled(meeting == nil)
            Divider()
            Button("Quitter la réunion") { Task { await model.leaveMeeting() } }
                .keyboardShortcut("w")
                .disabled(meeting == nil)
        }
    }
}
