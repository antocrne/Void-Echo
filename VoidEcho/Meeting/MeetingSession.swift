import AppKit
import Observation
import WebKit

/// What the pre-join screen decided.
struct JoinOptions: Equatable {
    var displayName: String
    /// Device names as macOS gives them (WebKit labels devices the same way); nil: the default one.
    var cameraName: String?
    var microphoneName: String?
    var cameraOff: Bool
    var microphoneOff: Bool
}

/// One meeting: the Jitsi room in a web view, and what Void Echo knows of it. Only one exists at a
/// time (AppModel). The page is Jitsi's own web app, loaded from the meeting's server: Void Echo
/// adds nothing to the call itself — it answers WebKit's questions (camera, microphone, screen,
/// windows the page opens) and drives Jitsi's toolbar from the menu.
@MainActor @Observable
final class MeetingSession: NSObject {
    let room: MeetingRoom
    let options: JoinOptions

    // Reported by Jitsi (MeetingScripts.bridge).
    private(set) var joined = false
    private(set) var audioMuted: Bool
    private(set) var videoMuted: Bool
    private(set) var sharingScreen = false
    /// nil until the page has said whether WebKit gives it `getDisplayMedia`.
    private(set) var screenShareSupported: Bool?
    /// Jitsi answered (its `APP` object exists): the menu commands go through its toolbar.
    private(set) var bridgeReady = false

    /// Devices the page asked for but macOS refuses to Void Echo.
    var deniedDevices: [MediaKind] = []
    /// The page couldn't be loaded: shown over the web view, with "Réessayer".
    private(set) var loadError: String?
    private(set) var isLoading = true

    @ObservationIgnored private(set) var webView: WKWebView!
    @ObservationIgnored private var popups: [PopupWindowController] = []
    @ObservationIgnored private var captureObservations: [NSKeyValueObservation] = []
    /// Called when Jitsi leaves the room by itself (its hang-up button, a kick, the end of the
    /// meeting): the app goes back home.
    @ObservationIgnored var onEnded: (() -> Void)?

    init(room: MeetingRoom, options: JoinOptions) {
        self.room = room
        self.options = options
        audioMuted = options.microphoneOff
        videoMuted = options.cameraOff
        super.init()
        webView = makeWebView()
        load()
    }

    /// The room's link with the pre-join screen's choices, in the form Jitsi reads at load
    /// ("#config.startWithAudioMuted=true&userInfo.displayName=…"). All of them are in the list
    /// of settings Jitsi lets a link override. Turning Jitsi's own pre-join page off makes it
    /// enter without opening any device (its safeguard against links that would switch a camera
    /// on): the microphone and the camera chosen are then turned on by MeetingScripts.bridge.
    var meetingURL: URL {
        let settings: [(String, Any)] = [
            ("config.prejoinConfig.enabled", false),
            ("config.prejoinPageEnabled", false),
            ("config.startWithAudioMuted", options.microphoneOff),
            ("config.startWithVideoMuted", options.cameraOff),
            ("config.disableDeepLinking", true),
            ("userInfo.displayName", options.displayName),
        ]
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let fragment = settings.map { key, value in
            let json = (try? JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed))
                .flatMap { String(data: $0, encoding: .utf8) } ?? "\"\""
            return "\(key)=\(json.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
        }.joined(separator: "&")
        var components = URLComponents(url: room.url, resolvingAgainstBaseURL: false)!
        components.percentEncodedFragment = fragment
        return components.url!
    }

    func load() {
        loadError = nil
        isLoading = true
        webView.load(URLRequest(url: meetingURL))
    }

    // MARK: Commands (menu, ⌘D, ⌘E)

    func toggleMicrophone() {
        Task {
            if await call("return window.__voidEcho ? window.__voidEcho.toggleAudio() : false") as? Bool == true { return }
            // Without Jitsi's toolbar (page still loading, or a server whose Jitsi differs), WebKit
            // mutes the microphone itself.
            let muted = webView.microphoneCaptureState == .active
            await webView.setMicrophoneCaptureState(muted ? .muted : .active)
            audioMuted = muted
        }
    }

    func toggleCamera() {
        Task {
            if await call("return window.__voidEcho ? window.__voidEcho.toggleVideo() : false") as? Bool == true { return }
            let muted = webView.cameraCaptureState == .active
            await webView.setCameraCaptureState(muted ? .muted : .active)
            videoMuted = muted
        }
    }

    /// Leaves the room properly (the others see you leave at once), then releases the camera,
    /// the microphone and the page. At most a second and a half: a server that doesn't answer
    /// doesn't keep the user in.
    func leave() async {
        onEnded = nil
        _ = await withTaskGroup(of: Void.self) { group in
            group.addTask { @MainActor in _ = await self.call("return window.__voidEcho ? await window.__voidEcho.leave() : false") }
            group.addTask { try? await Task.sleep(for: .milliseconds(1500)) }
            await group.next()
            group.cancelAll()
        }
        close()
    }

    /// Stops everything at once: devices, page, the windows it opened.
    func close() {
        onEnded = nil
        captureObservations.removeAll()
        popups.forEach { $0.close() }
        popups.removeAll()
        guard let webView else { return }
        webView.setCameraCaptureState(.none, completionHandler: nil)
        webView.setMicrophoneCaptureState(.none, completionHandler: nil)
        webView.stopLoading()
        webView.configuration.userContentController.removeAllScriptMessageHandlers()
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.loadHTMLString("", baseURL: nil)
        webView.removeFromSuperview()
    }

    @discardableResult
    private func call(_ script: String) async -> Any? {
        guard let webView else { return nil }
        return try? await webView.callAsyncJavaScript(script, contentWorld: .page)
    }

    // MARK: Web view

    private func makeWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        // Persistent: Jitsi keeps its own settings (volume, layout…) from one meeting to the next.
        config.websiteDataStore = .default()
        // Jitsi only supports the browsers it knows: in a web view WebKit says "Safari" only
        // with this suffix (Safari's own version where it can be read).
        config.applicationNameForUserAgent = "Version/\(Self.safariVersion) Safari/605.1.15"
        config.mediaTypesRequiringUserActionForPlayback = []
        config.preferences.isElementFullscreenEnabled = true
        // Jitsi opens the hosts' sign-in window (meet.jit.si) after a request to its server, once
        // WebKit no longer counts the click: blocked, it says "Login popup was blocked". The page
        // is the meeting's own server; what it opens goes to a small Void Echo window.
        config.preferences.javaScriptCanOpenWindowsAutomatically = true

        let controller = config.userContentController
        controller.addUserScript(WKUserScript(
            source: MeetingScripts.devicePreferences(cameraLabel: options.cameraName, microphoneLabel: options.microphoneName),
            injectionTime: .atDocumentStart, forMainFrameOnly: true, in: .page))
        controller.addUserScript(WKUserScript(
            source: MeetingScripts.bridge(microphoneOn: !options.microphoneOff, cameraOn: !options.cameraOff),
            injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: .page))
        controller.add(WeakMessageHandler(self), contentWorld: .page, name: MeetingScripts.handlerName)

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsMagnification = false
        webView.underPageBackgroundColor = .black
        #if DEBUG
        webView.isInspectable = true
        #endif
        // WebKit's own view of the devices: the truth when the page can't tell (see toggleMicrophone).
        captureObservations = [
            webView.observe(\.microphoneCaptureState) { [weak self] view, _ in
                MainActor.assumeIsolated { if self?.bridgeReady == false { self?.audioMuted = view.microphoneCaptureState != .active } }
            },
            webView.observe(\.cameraCaptureState) { [weak self] view, _ in
                MainActor.assumeIsolated { if self?.bridgeReady == false { self?.videoMuted = view.cameraCaptureState != .active } }
            },
        ]
        return webView
    }

    private static let safariVersion: String = {
        (Bundle(path: "/Applications/Safari.app")?.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "18.0"
    }()

    fileprivate func receive(_ body: Any) {
        guard let state = body as? [String: Any] else { return }
        bridgeReady = true
        joined = state["joined"] as? Bool ?? joined
        audioMuted = state["audioMuted"] as? Bool ?? audioMuted
        videoMuted = state["videoMuted"] as? Bool ?? videoMuted
        sharingScreen = state["sharing"] as? Bool ?? sharingScreen
        screenShareSupported = state["screenShareSupported"] as? Bool
    }

    /// The meeting's own pages: its server, at the room's path (with or without a sign-in token).
    private func isRoomPage(_ url: URL) -> Bool {
        guard url.host()?.lowercased() == room.server.host, url.port == room.server.baseURL.port else { return false }
        return url.path(percentEncoded: false).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            == room.url.path(percentEncoded: false).lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func isMeetingOrigin(_ origin: WKSecurityOrigin) -> Bool {
        origin.protocol == "https" && origin.host.lowercased() == room.server.host
    }

    private func popupClosed(_ popup: PopupWindowController) {
        popups.removeAll { $0 === popup }
    }
}

// MARK: - Navigation

extension MeetingSession: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard action.targetFrame?.isMainFrame ?? true, let url = action.request.url else { return .allow }
        if url.scheme == "about" || isRoomPage(url) { return .allow }
        if url.host()?.lowercased() == room.server.host {
            // Jitsi leaving the room: its home page or its "merci" page after hanging up.
            onEnded?()
            return .cancel
        }
        if action.navigationType == .linkActivated {
            NSWorkspace.shared.open(url)
            return .cancel
        }
        // A sign-in that goes through another site and comes back to the room.
        return url.scheme == "https" ? .allow : .cancel
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        isLoading = false
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        fail(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        fail(error)
    }

    private func fail(_ error: Error) {
        let error = error as NSError
        // A navigation Void Echo cancelled itself, or replaced by another.
        guard error.code != NSURLErrorCancelled, !(error.domain == WKError.errorDomain && error.code == 102) else { return }
        isLoading = false
        loadError = error.domain == NSURLErrorDomain && [NSURLErrorCannotFindHost, NSURLErrorCannotConnectToHost, NSURLErrorDNSLookupFailed].contains(error.code)
            ? "Le serveur \(room.server.displayName) est introuvable. Vérifiez l'adresse dans Réglages → Serveur Jitsi."
            : error.localizedDescription
    }

    /// The page's process crashed (memory, GPU…): reload the room rather than leave a blank window.
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        load()
    }
}

// MARK: - Permissions, dialogs, windows

extension MeetingSession: WKUIDelegate {
    /// Camera and microphone. Only the meeting's server gets them, and only once macOS grants
    /// them to Void Echo; otherwise the page gets a clear refusal (never an unanswered request,
    /// which would leave Jitsi waiting) and Void Echo explains how to allow it.
    /// The async name is the one WebKit looks for: under any other, it refuses by itself.
    func webView(_ webView: WKWebView, decideMediaCapturePermissionsFor origin: WKSecurityOrigin,
                 initiatedBy frame: WKFrameInfo, type: WKMediaCaptureType) async -> WKPermissionDecision {
        guard isMeetingOrigin(origin) else { return .deny }
        let kinds: [MediaKind] = switch type {
        case .camera: [.camera]
        case .microphone: [.microphone]
        default: [.camera, .microphone]
        }
        var denied: [MediaKind] = []
        for kind in kinds where await !MediaAccess.request(kind) { denied.append(kind) }
        for kind in denied where !deniedDevices.contains(kind) { deniedDevices.append(kind) }
        #if DEBUG
        DebugProbe.log("media capture \(kinds.map(\.rawValue)) from \(origin.host): \(denied.isEmpty ? "granted" : "denied")")
        #endif
        return denied.isEmpty ? .grant : .deny
    }

    /// Screen sharing (getDisplayMedia, WKUIDelegatePrivate). WebKit takes 0 (refuse), 1 (a screen)
    /// or 2 (a window). Tested: in an app's web view, 1 starts sharing the screen at once, without
    /// any chooser — so Void Echo asks first, and says what will be shown. Called by its selector:
    /// without it, WebKit refuses every screen share by itself.
    @objc(_webView:requestDisplayCapturePermissionForOrigin:initiatedByFrame:withSystemAudio:decisionHandler:)
    func webViewRequestDisplayCapture(_ webView: WKWebView, for origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo,
                                      withSystemAudio: Bool, decisionHandler: @escaping (Int) -> Void) {
        #if DEBUG
        DebugProbe.log("display capture from \(origin.host), system audio: \(withSystemAudio)")
        #endif
        guard isMeetingOrigin(origin), let window = webView.window else { return decisionHandler(0) }
        let alert = NSAlert()
        alert.messageText = "Que voulez-vous partager ?"
        alert.informativeText = "Les participants verront ce que vous choisissez jusqu'à ce que vous arrêtiez le partage (dans la réunion, ou depuis l'icône de partage de la barre des menus). Le son de l'ordinateur n'est pas partagé."
        alert.addButton(withTitle: "Une fenêtre…")
        alert.addButton(withTitle: "Tout l'écran")
        alert.addButton(withTitle: "Annuler")
        alert.beginSheetModal(for: window) { response in
            switch response {
            case .alertFirstButtonReturn: decisionHandler(2)
            case .alertSecondButtonReturn: decisionHandler(1)
            default: decisionHandler(0)
            }
        }
    }

    /// Notifications (WKUIDelegatePrivate): refused — Void Echo's window is the meeting.
    @objc(_webView:requestNotificationPermissionForSecurityOrigin:decisionHandler:)
    func webViewRequestNotificationPermission(_ webView: WKWebView, for origin: WKSecurityOrigin, decisionHandler: @escaping (Bool) -> Void) {
        decisionHandler(false)
    }

    /// Location (WKUIDelegatePrivate): refused — a meeting doesn't need it.
    @objc(_webView:requestGeolocationPermissionForOrigin:initiatedByFrame:decisionHandler:)
    func webViewRequestGeolocation(_ webView: WKWebView, for origin: WKSecurityOrigin, initiatedByFrame frame: WKFrameInfo,
                                   decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.deny)
    }

    /// A window the page opens on a click: the hosts' sign-in on meet.jit.si, a link of the chat.
    /// Shown in a small window of Void Echo, which keeps the link with the meeting (the sign-in
    /// sends its answer back to it).
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        let popup = PopupWindowController(configuration: configuration, parent: webView.window) { [weak self] popup in
            self?.popupClosed(popup)
        }
        popups.append(popup)
        popup.show()
        return popup.webView
    }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo) async {
        _ = await present(message: message, buttons: ["OK"])
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo) async -> Bool {
        await present(message: message, buttons: ["OK", "Annuler"]) == .alertFirstButtonReturn
    }

    private func present(message: String, buttons: [String]) async -> NSApplication.ModalResponse {
        let alert = NSAlert()
        alert.messageText = room.server.displayName
        alert.informativeText = message
        buttons.forEach { alert.addButton(withTitle: $0) }
        guard let window = webView.window else { return alert.runModal() }
        return await alert.beginSheetModal(for: window)
    }
}

/// The content controller keeps its handlers: through this, it doesn't keep the session.
private final class WeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var session: MeetingSession?

    init(_ session: MeetingSession) { self.session = session }

    func userContentController(_ controller: WKUserContentController, didReceive message: WKScriptMessage) {
        MainActor.assumeIsolated { session?.receive(message.body) }
    }
}
