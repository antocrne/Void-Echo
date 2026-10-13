import AppKit
import SwiftUI

/// Gives access to the hosting NSWindow to configure it once.
struct WindowAccessor: NSViewRepresentable {
    let configure: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async { [weak view] in
            if let window = view?.window { configure(window) }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// What is behind the window (desktop, other apps), blurred: under a tinted frame. Stays frosted
/// in an inactive window; "Réduire la transparence" makes it opaque.
struct BehindWindowBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .underWindowBackground
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {}
}

/// The top bar is also the window's title bar, where macOS would move the window from anywhere
/// — tabs included, before they can be dragged. While this view is in a window, the window
/// can't be moved by the system; it moves only from the bar's empty places (this view, behind
/// the bar's content), and a double-click there does what the title bar's would.
struct TitleBarDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DragView { DragView() }
    func updateNSView(_ view: DragView, context: Context) {}

    final class DragView: NSView {
        override var mouseDownCanMoveWindow: Bool { false }
        /// As a title bar: an inactive window is moved by its first click.
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

        override func viewWillMove(toWindow newWindow: NSWindow?) {
            super.viewWillMove(toWindow: newWindow)
            // Back to the sidebar layout: the window is movable by its background again.
            if newWindow == nil { window?.isMovable = true }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            window?.isMovable = false
        }

        override func mouseDown(with event: NSEvent) {
            guard let window else { return }
            if event.clickCount == 2 {
                switch UserDefaults.standard.string(forKey: "AppleActionOnDoubleClick") {
                case "Minimize": window.miniaturize(nil)
                case "None": break
                default: window.zoom(nil)
                }
                return
            }
            // The pointer keeps its place in the window while the window follows it.
            let grab = event.locationInWindow
            while let next = window.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]), next.type == .leftMouseDragged {
                let pointer = window.convertPoint(toScreen: next.locationInWindow)
                window.setFrameOrigin(NSPoint(x: pointer.x - grab.x, y: pointer.y - grab.y))
            }
        }
    }
}

/// Moves the window's traffic lights down so they share a centre line with the chrome's first
/// row of buttons (macOS centres them 16 pt from the top, our rows sit lower). AppKit lays the
/// title bar out again on resize or key changes, so the offset is reapplied whenever a button moves.
struct TrafficLightsAlignment: NSViewRepresentable {
    /// Distance from the window's top edge to the buttons' centre.
    let centerY: CGFloat

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ view: NSView, context: Context) {
        context.coordinator.centerY = centerY
        DispatchQueue.main.async { [weak view] in
            guard let window = view?.window else { return }
            context.coordinator.attach(to: window)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var centerY: CGFloat = 16
        private weak var window: NSWindow?
        private var observers: [NSObjectProtocol] = []
        private var applyPending = false

        deinit { observers.forEach(NotificationCenter.default.removeObserver) }

        func attach(to window: NSWindow) {
            if self.window !== window {
                self.window = window
                observers.forEach(NotificationCenter.default.removeObserver)
                observers = buttons(of: window).map { button in
                    button.postsFrameChangedNotifications = true
                    return NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: button, queue: .main) { [weak self] _ in
                        self?.scheduleApply()
                    }
                }
            }
            apply()
        }

        /// AppKit puts the buttons back one after the other during its title bar layout: moving
        /// them from inside that pass loses to the next reset (the last one, zoom, stayed up).
        /// Waiting for the pass to end moves all three once it is done.
        private func scheduleApply() {
            guard !applyPending else { return }
            applyPending = true
            DispatchQueue.main.async { [weak self] in
                self?.applyPending = false
                self?.apply()
            }
        }

        private func buttons(of window: NSWindow) -> [NSButton] {
            [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton].compactMap { window.standardWindowButton($0) }
        }

        private func apply() {
            // Full screen: the buttons live in the menu-bar reveal, leave them where macOS puts them.
            guard let window, !window.styleMask.contains(.fullScreen) else { return }
            for button in buttons(of: window) {
                guard let titleBar = button.superview else { continue }
                let fromTop = centerY - button.frame.height / 2
                let y = titleBar.isFlipped ? fromTop : titleBar.bounds.height - fromTop - button.frame.height
                // Setting the same origin posts no notification, so this doesn't loop.
                if button.frame.origin.y != y { button.setFrameOrigin(NSPoint(x: button.frame.origin.x, y: y)) }
            }
        }
    }
}
