import SwiftUI
import WebKit

/// The meeting: Jitsi's page over the whole window, and only what Void Echo has to say over it —
/// a device macOS refuses, a page that couldn't load.
struct MeetingView: View {
    let session: MeetingSession
    @Environment(AppModel.self) private var model

    var body: some View {
        ZStack(alignment: .top) {
            MeetingWebView(webView: session.webView)
                .background(Color.black)

            if let error = session.loadError {
                LoadErrorView(message: error, retry: session.load) {
                    Task { await model.leaveMeeting() }
                }
            } else if session.isLoading {
                ProgressView()
                    .controlSize(.small)
                    .tint(Theme.onVideo)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)
            }

            if !session.deniedDevices.isEmpty {
                DeniedDevicesBanner(kinds: session.deniedDevices) { session.deniedDevices = [] }
                    .padding(.top, 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Theme.quick, value: session.deniedDevices)
    }
}

/// The session's web view, kept by the session: the view is only where it's shown.
private struct MeetingWebView: NSViewRepresentable {
    let webView: WKWebView

    func makeNSView(context: Context) -> NSView {
        let container = NSView()
        attach(to: container)
        return container
    }

    func updateNSView(_ container: NSView, context: Context) {
        if webView.superview !== container { attach(to: container) }
    }

    private func attach(to container: NSView) {
        webView.removeFromSuperview()
        webView.frame = container.bounds
        webView.autoresizingMask = [.width, .height]
        container.addSubview(webView)
        DispatchQueue.main.async { webView.window?.makeFirstResponder(webView) }
    }
}

/// macOS refuses the camera or the microphone to Void Echo: the meeting goes on, but without
/// them; the button opens the right panel of Réglages Système.
struct DeniedDevicesBanner: View {
    let kinds: [MediaKind]
    var dismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: kinds.contains(.camera) ? "video.slash.fill" : "mic.slash.fill")
                .foregroundStyle(Theme.danger)
            VStack(alignment: .leading, spacing: 2) {
                Text(MediaAccess.deniedMessage(kinds)).fontWeight(.semibold)
                Text(MediaAccess.deniedExplanation)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Button("Ouvrir Réglages Système") { MediaAccess.openSystemSettings(kinds[0]) }
                .voidPrimaryButton()
            if let dismiss {
                ChromeButton(symbol: "xmark", help: "Masquer", size: 11, action: dismiss)
            }
        }
        .padding(12)
        .frame(maxWidth: 620)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Theme.elevated))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.stroke))
        .shadow(color: Theme.shadow.opacity(0.25), radius: 12, y: 4)
        .padding(.horizontal, 16)
    }
}

private struct LoadErrorView: View {
    let message: String
    let retry: () -> Void
    let back: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(Theme.secondaryText)
            Text("La réunion n'a pas pu s'ouvrir")
                .font(.system(size: 17, weight: .semibold))
            Text(message)
                .foregroundStyle(Theme.secondaryText)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
            HStack {
                Button("Retour à l'accueil", action: back).voidSecondaryButton()
                Button("Réessayer", action: retry).voidPrimaryButton()
            }
            .controlSize(.large)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.chrome)
    }
}

/// In a meeting, the window's top bar shows the room, centered…
struct MeetingBarTitle: View {
    let session: MeetingSession

    var body: some View {
        VStack(spacing: 0) {
            Text(session.room.displayName)
                .font(.system(size: 12, weight: .semibold))
            Text(session.room.server.displayName)
                .font(.system(size: 10.5))
                .foregroundStyle(Theme.secondaryText)
        }
        .lineLimit(1)
        .truncationMode(.middle)
    }
}

/// …and three actions on the right; Jitsi's own toolbar does the rest.
struct MeetingBarActions: View {
    let session: MeetingSession
    @Environment(AppModel.self) private var model

    var body: some View {
        if session.screenShareSupported == false {
            ScreenShareUnavailableButton()
        }
        let copied = model.copiedLink == session.room.link
        ChromeButton(symbol: copied ? "checkmark" : "link", help: copied ? "Lien copié" : "Copier le lien de la réunion (⇧⌘C)",
                     active: copied) { model.copyLink(session.room) }
        ChromeButton(symbol: "safari", help: "Continuer dans le navigateur") { Task { await model.openInBrowser() } }
        ChromeButton(symbol: "phone.down.fill", help: "Quitter la réunion (⌘W)") { Task { await model.leaveMeeting() } }
    }
}

/// When WebKit gives the page no screen sharing: says so, rather than a button that does nothing.
private struct ScreenShareUnavailableButton: View {
    @Environment(AppModel.self) private var model
    @State private var showing = false

    var body: some View {
        ChromeButton(symbol: "rectangle.on.rectangle.slash", help: "Partage d'écran indisponible ici") { showing = true }
            .popover(isPresented: $showing, arrowEdge: .bottom) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Partage d'écran indisponible").font(.headline)
                    Text("Cette version de macOS ne permet pas à Void Echo de partager l'écran dans la réunion. Pour le faire, continuez la réunion dans votre navigateur : Void Echo la quitte, le navigateur la rouvre.")
                        .fixedSize(horizontal: false, vertical: true)
                        .foregroundStyle(Theme.secondaryText)
                    Button("Continuer dans le navigateur") { Task { await model.openInBrowser() } }
                        .voidPrimaryButton()
                }
                .padding(16)
                .frame(width: 320)
            }
    }
}
