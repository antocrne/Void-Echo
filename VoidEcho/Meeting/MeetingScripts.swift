import Foundation

/// The JavaScript Void Echo adds to the meeting page. Both run in the page's own world: they need
/// Jitsi's objects (`APP`) and `navigator.mediaDevices` as Jitsi sees them.
enum MeetingScripts {
    /// Name of the message handler the bridge posts the meeting's state to.
    static let handlerName = "voidEcho"

    /// Before Jitsi's own scripts: the camera and the microphone chosen on the pre-join screen.
    /// WebKit doesn't let the app pick a device, and Jitsi only takes devices from its own
    /// settings. So: Jitsi's remembered choice is replaced by the labels chosen here (Jitsi matches
    /// devices by label when their IDs differ), and a request that names no device gets the chosen
    /// one. A request naming a device (a switch in Jitsi's own settings, during the meeting) is
    /// left alone.
    static func devicePreferences(cameraLabel: String?, microphoneLabel: String?) -> String {
        let prefs: [String: String?] = ["camera": cameraLabel, "microphone": microphoneLabel]
        let json = (try? JSONSerialization.data(withJSONObject: prefs.mapValues { $0 ?? NSNull() as Any }))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        return """
        (() => {
          const prefs = \(json);
          try {
            const key = 'features/base/settings';
            const saved = JSON.parse(localStorage.getItem(key) || '{}') || {};
            for (const k of ['cameraDeviceId', 'micDeviceId', 'userSelectedCameraDeviceId', 'userSelectedMicDeviceId',
                             'userSelectedCameraDeviceLabel', 'userSelectedMicDeviceLabel']) delete saved[k];
            if (prefs.camera) saved.userSelectedCameraDeviceLabel = prefs.camera;
            if (prefs.microphone) saved.userSelectedMicDeviceLabel = prefs.microphone;
            localStorage.setItem(key, JSON.stringify(saved));
          } catch (e) {}

          // On the prototype: at document start, `navigator.mediaDevices` isn't usable yet.
          const proto = window.MediaDevices && MediaDevices.prototype;
          if (!proto || !proto.getUserMedia || (!prefs.camera && !prefs.microphone)) return;
          const original = proto.getUserMedia;
          const simplify = s => (s || '').toLowerCase().replace(/\\s*\\([0-9a-f]{4}:[0-9a-f]{4}\\)\\s*$/, '').replace(/\\s#\\d+$/, '').trim();
          const known = {};
          async function find(md, kind, label) {
            if (known[kind]) return known[kind];
            const devices = await md.enumerateDevices();
            const match = devices.find(d => d.kind === kind && d.label === label)
              || devices.find(d => d.kind === kind && d.label && simplify(d.label) === simplify(label));
            if (match) known[kind] = match.deviceId;
            return match ? match.deviceId : null;
          }
          proto.getUserMedia = async function (constraints) {
            const md = this;
            let wanted = constraints;
            try {
              const wishes = [['video', 'videoinput', prefs.camera], ['audio', 'audioinput', prefs.microphone]]
                .filter(([key, , label]) => label && constraints && constraints[key]
                        && !(typeof constraints[key] === 'object' && constraints[key].deviceId));
              if (wishes.length) {
                // Before the first permission, WebKit lists devices without their names.
                if (wishes.some(([, kind]) => !known[kind]) && (await md.enumerateDevices()).every(d => !d.label)) {
                  const probe = await original.call(md, Object.fromEntries(wishes.map(([key]) => [key, true])));
                  probe.getTracks().forEach(t => t.stop());
                }
                wanted = Object.assign({}, constraints);
                for (const [key, kind, label] of wishes) {
                  const id = await find(md, kind, label);
                  if (id) wanted[key] = Object.assign({}, constraints[key] === true ? {} : constraints[key], { deviceId: { exact: id } });
                }
              }
            } catch (e) { wanted = constraints; }
            try { return await original.call(md, wanted); }
            catch (e) { if (wanted !== constraints) return original.call(md, constraints); throw e; }
          };
        })();
        """
    }

    /// Once Jitsi has started: tells Void Echo whether the microphone and the camera are on, whether
    /// the meeting is joined and whether the screen is shared; and gives Void Echo the commands
    /// of its menu (⌘D, ⌘E, ⌘W). `APP` is Jitsi's own object, the one its toolbar uses.
    ///
    /// Jitsi enters "without media" when a link turns its own pre-join page off (a safeguard
    /// against links that would switch a camera on). The choice was made on Void Echo's pre-join
    /// screen: once the room is joined, the microphone and the camera chosen there are turned on.
    /// On/off is read from Jitsi's local tracks: before a device was ever opened, Jitsi's own
    /// "is muted" says no while nothing is on.
    static func bridge(microphoneOn: Bool, cameraOn: Bool) -> String {
        """
        (() => {
          if (window.__voidEcho) return;
          const wanted = { audio: \(microphoneOn), video: \(cameraOn) };
          const post = m => { try { window.webkit.messageHandlers.\(handlerName).postMessage(m); } catch (e) {} };
          const ready = () => window.APP && APP.store && APP.conference;
          const track = type => (APP.store.getState()['features/base/tracks'] || []).find(t => t.local && t.mediaType === type);
          const isOn = type => { const t = track(type); return !!t && !t.muted; };
          window.__voidEcho = {
            setAudio(on) { if (!ready()) return false; APP.conference.muteAudio(!on); return true; },
            setVideo(on) { if (!ready()) return false; APP.conference.muteVideo(!on); return true; },
            toggleAudio() { return this.setAudio(!isOn('audio')); },
            toggleVideo() { return this.setVideo(!isOn('video')); },
            async leave() { if (!ready()) return false; try { await APP.conference.leaveRoom(); } catch (e) {} return true; },
          };
          let last = '', applied = false;
          function report() {
            const s = APP.store.getState();
            const conference = s['features/base/conference'] || {};
            const tracks = s['features/base/tracks'] || [];
            const joined = !!conference.conference;
            if (joined && !applied) {
              applied = true;
              if (wanted.audio && !track('audio')) window.__voidEcho.setAudio(true);
              if (wanted.video && !track('video')) window.__voidEcho.setVideo(true);
            }
            const state = {
              joined,
              audioMuted: !isOn('audio'),
              videoMuted: !isOn('video'),
              sharing: tracks.some(t => t.local && (t.mediaType === 'screenshare' || t.videoType === 'desktop')),
              screenShareSupported: !!(navigator.mediaDevices && navigator.mediaDevices.getDisplayMedia),
            };
            const text = JSON.stringify(state);
            if (text !== last) { last = text; post(state); }
          }
          const timer = setInterval(() => {
            if (!ready()) return;
            clearInterval(timer);
            report();
            APP.store.subscribe(report);
          }, 250);
        })();
        """
    }
}
