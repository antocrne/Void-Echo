import AppKit
import WebKit

/// A window the meeting page opens (window.open on a click): the sign-in of meet.jit.si's hosts,
/// a link of the chat. A plain small window with the page and, in its title bar, the site's
/// address and "Ouvrir dans le navigateur". It closes when the page closes itself (the sign-in,
/// once done) or with the meeting.
@MainActor
final class PopupWindowController: NSWindowController, NSWindowDelegate, WKUIDelegate, WKNavigationDelegate {
    let webView: WKWebView
    private let onClose: (PopupWindowController) -> Void
    private var titleObservation: NSKeyValueObservation?

    init(configuration: WKWebViewConfiguration, parent: NSWindow?, onClose: @escaping (PopupWindowController) -> Void) {
        webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 520, height: 640), configuration: configuration)
        self.onClose = onClose
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 640),
                              styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed
        window.backgroundColor = Theme.chromeNS
        window.contentView = webView
        super.init(window: window)
        window.delegate = self
        webView.uiDelegate = self
        webView.navigationDelegate = self

        let open = NSButton(title: "Ouvrir dans le navigateur", target: self, action: #selector(openInBrowser))
        open.bezelStyle = .accessoryBarAction
        open.controlSize = .small
        let accessory = NSTitlebarAccessoryViewController()
        accessory.view = NSView(frame: NSRect(x: 0, y: 0, width: open.fittingSize.width + 12, height: 28))
        open.frame.origin = NSPoint(x: 0, y: (28 - open.fittingSize.height) / 2)
        open.setFrameSize(open.fittingSize)
        accessory.view.addSubview(open)
        accessory.layoutAttribute = .trailing
        window.addTitlebarAccessoryViewController(accessory)

        titleObservation = webView.observe(\.url) { [weak self] view, _ in
            MainActor.assumeIsolated { self?.window?.title = view.url?.host() ?? "Void Echo" }
        }
        if let parent {
            let frame = parent.frame
            window.setFrameOrigin(NSPoint(x: frame.midX - 260, y: frame.midY - 320))
        } else {
            window.center()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    func show() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    override func close() {
        webView.stopLoading()
        super.close()
    }

    @objc private func openInBrowser() {
        if let url = webView.url { NSWorkspace.shared.open(url) }
    }

    func windowWillClose(_ notification: Notification) {
        titleObservation = nil
        onClose(self)
    }

    /// window.close() from the page: the sign-in is done.
    func webViewDidClose(_ webView: WKWebView) {
        close()
    }

    /// A popup opening another one: same small window, the chain stays linked to the meeting.
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for action: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        webView.load(action.request)
        return nil
    }

    /// No camera, microphone or screen for the pages of these windows.
    func webView(_ webView: WKWebView, decideMediaCapturePermissionsFor origin: WKSecurityOrigin,
                 initiatedBy frame: WKFrameInfo, type: WKMediaCaptureType) async -> WKPermissionDecision {
        .deny
    }
}
