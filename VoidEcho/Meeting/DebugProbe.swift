#if DEBUG
import Foundation
import WebKit

/// Debug builds only: lets the manual tests read the meeting page's state from the Terminal.
/// A script written to `<container>/tmp/probe.js` runs in the meeting page (an async function
/// body: `return …`), and its result lands in `probe.out` next to it. The container is
/// ~/Library/Containers/app.void.echo/Data/tmp.
@MainActor
enum DebugProbe {
    private static var timer: Timer?

    static func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            MainActor.assumeIsolated { poll() }
        }
    }

    private static func poll() {
        let folder = FileManager.default.temporaryDirectory
        let input = folder.appending(path: "probe.js"), output = folder.appending(path: "probe.out")
        guard let script = try? String(contentsOf: input, encoding: .utf8) else { return }
        try? FileManager.default.removeItem(at: input)
        guard let webView = AppModel.shared.meeting?.webView else {
            try? "no meeting".write(to: output, atomically: true, encoding: .utf8)
            return
        }
        Task {
            let text: String
            do {
                let value = try await webView.callAsyncJavaScript(script, contentWorld: .page)
                if let value, JSONSerialization.isValidJSONObject(value),
                   let data = try? JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]) {
                    text = String(decoding: data, as: UTF8.self)
                } else {
                    text = String(describing: value ?? "nil")
                }
            } catch {
                text = "error: \(error)"
            }
            try? text.write(to: output, atomically: true, encoding: .utf8)
        }
    }

    /// Appends to `<container>/tmp/probe.log`.
    static func log(_ message: String) {
        let url = FileManager.default.temporaryDirectory.appending(path: "probe.log")
        let line = Data("\(Date().formatted(.iso8601)) \(message)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(line)
            try? handle.close()
        } else {
            try? line.write(to: url)
        }
    }
}
#endif
