import AppKit
import SwiftUI

/// The five accent colors offered in Réglages → Couleur — the same pastel tones as Void (OKLCH:
/// lightness 0.74 and chroma 0.095 for the light theme, 0.80 and about 0.09 for the dark one).
/// As in Void, softness over contrast in the light theme: an accent text or icon reaches only
/// about 2:1 there; in the dark theme, at least 8:1. Labels on an accent fill (primary buttons)
/// are dark (`Theme.onAccent`, at least 7.5:1), never white.
enum AccentChoice: String, CaseIterable, Identifiable {
    case violet, blue, green, orange, pink
    var id: String { rawValue }

    var label: String {
        switch self {
        case .violet: "Violet"
        case .blue: "Bleu"
        case .green: "Vert"
        case .orange: "Orange"
        case .pink: "Rose"
        }
    }

    /// Text / icon tone on light backgrounds; also the fill behind dark labels.
    var lightHex: UInt32 {
        switch self {
        case .violet: 0xA7A2E4
        case .blue: 0x84ADE7
        case .green: 0x7BBC8E
        case .orange: 0xD89C6D
        case .pink: 0xDB92AE
        }
    }

    /// Text / icon tone on dark backgrounds.
    var darkHex: UInt32 {
        switch self {
        case .violet: 0xBAB5F4
        case .blue: 0x9EC0F0
        case .green: 0x91CFA3
        case .orange: 0xE7B188
        case .pink: 0xEEA5C1
        }
    }
}

/// Void Echo's palette — the only place where colors are defined (Void's; the frame's tints are
/// computed in ChromeTint.swift). Every color adapts to the current appearance (dark by default);
/// the accent follows Réglages → Couleur and the frame Réglages → Teinte de la fenêtre, live.
enum Theme {
    /// The window's frame, flat: neutral or tinted.
    @MainActor static var chrome: Color { Color(nsColor: chromeNS) }
    /// A tinted frame over the blurred desktop: lightly translucent.
    static let translucentChromeOpacity = 0.82
    static let surface = dynamic(light: NSColor(hex: 0xFFFFFF), dark: NSColor(hex: 0x17171C))
    static let elevated = dynamic(light: NSColor(hex: 0xFFFFFF), dark: NSColor(hex: 0x1D1D23))
    static let hover = dynamic(light: NSColor(white: 0, alpha: 0.05), dark: NSColor(white: 1, alpha: 0.055))
    static let stroke = dynamic(light: NSColor(white: 0, alpha: 0.08), dark: NSColor(white: 1, alpha: 0.08))
    static let primaryText = dynamic(light: NSColor(hex: 0x131316), dark: NSColor(hex: 0xECECF1))
    /// Cool grey on the neutral frame; warm grey, lighter in the dark theme, on a tinted one (its
    /// warm base and up to 20 % of color): at least 4.5:1 on the frame in both cases.
    @MainActor static var secondaryText: Color {
        AppSettings.shared.chromeTint == .none ? secondaryTextNeutral : secondaryTextWarm
    }
    private static let secondaryTextNeutral = dynamic(light: NSColor(hex: 0x62626B), dark: NSColor(hex: 0x8B8B96))
    private static let secondaryTextWarm = dynamic(light: NSColor(hex: 0x5E5A55), dark: NSColor(hex: 0xBCB7B0))
    static let danger = dynamic(light: NSColor(hex: 0xC4262E), dark: NSColor(hex: 0xFF6B6B))
    static let switchOff = dynamic(light: NSColor(white: 0, alpha: 0.14), dark: NSColor(white: 1, alpha: 0.18))
    static let switchKnob = Color.white
    static let shadow = Color.black
    /// Behind the camera preview while it starts, and when the camera is off.
    static let videoBackground = Color(nsColor: NSColor(hex: 0x0B0B0E))
    /// Labels over the camera preview (always dark behind them).
    static let onVideo = Color.white
    static let onVideoControl = Color(nsColor: NSColor(white: 0, alpha: 0.45))
    /// A device the user turned off, over the preview: red, so it reads at a glance.
    static let mutedControl = Color(nsColor: NSColor(hex: 0xE5484D))
    /// Window background behind the chrome (AppKit side of `chrome`).
    @MainActor static var chromeNS: NSColor { AppSettings.shared.chromeLook.color }

    // MARK: Accent

    private struct AccentPalette {
        let accent: Color, fill: Color, soft: Color
    }

    private static let palettes: [AccentChoice: AccentPalette] = Dictionary(uniqueKeysWithValues: AccentChoice.allCases.map { choice in
        (choice, AccentPalette(
            accent: dynamic(light: NSColor(hex: choice.lightHex), dark: NSColor(hex: choice.darkHex)),
            fill: Color(nsColor: NSColor(hex: choice.lightHex)),
            soft: dynamic(light: NSColor(hex: choice.lightHex, alpha: 0.28), dark: NSColor(hex: choice.darkHex, alpha: 0.2))))
    })

    /// Icons, active controls, switches, focus rings, the microphone level.
    @MainActor static var accent: Color { palettes[AppSettings.shared.accent]!.accent }
    /// Solid fill behind `onAccent` text (primary buttons) — same tone in both themes.
    @MainActor static var accentFill: Color { palettes[AppSettings.shared.accent]!.fill }
    /// Text and symbols on `accentFill` / `accent` fills: dark, the pastel tones being light.
    static let onAccent = Color(nsColor: NSColor(hex: 0x131316))
    /// Tinted background: hovered history rows, "copié" confirmation.
    @MainActor static var accentSoft: Color { palettes[AppSettings.shared.accent]!.soft }

    static func swatch(_ choice: AccentChoice) -> Color { palettes[choice]!.accent }

    // MARK: Logo (brand colors, fixed)

    static let logoGradient = [NSColor(hex: 0xF4F1FF), NSColor(hex: 0x9D8FFF), NSColor(hex: 0x4B3FD0)].map { Color(nsColor: $0) }
    static let logoGlow = Color(nsColor: NSColor(hex: 0x9D8FFF, alpha: 0.55))
    static let logoCore = Color(nsColor: NSColor(hex: 0x07070A))
    /// The echo's arcs: pale on the dark frame (as on the icon), deeper on the light one, where the
    /// pale tone would vanish.
    static let logoEcho = dynamic(light: NSColor(hex: 0x7D6EEB), dark: NSColor(hex: 0xC4BAFF))

    static var spring: Animation? { animated(.spring(response: 0.32, dampingFraction: 0.86)) }
    static var quick: Animation? { animated(.easeOut(duration: 0.16)) }

    /// No motion when macOS is asked for less (Réglages Système → Accessibilité → Réduire les
    /// animations).
    private static func animated(_ animation: Animation) -> Animation? {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? nil : animation
    }

    static func dynamic(light: NSColor, dark: NSColor) -> Color {
        Color(nsColor: dynamicNS(light: light, dark: dark))
    }

    static func dynamicNS(light: NSColor, dark: NSColor) -> NSColor {
        NSColor(name: nil) { $0.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light }
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension View {
    /// Primary button: accent fill with a dark label (contrast checked for every accent).
    func voidPrimaryButton() -> some View {
        buttonStyle(PrimaryButtonStyle())
    }

    /// Secondary button of the same size: a faint fill, the label in the text color.
    func voidSecondaryButton() -> some View {
        buttonStyle(SecondaryButtonStyle())
    }

    /// Text field whose focus ring follows the accent color (the system ring follows the
    /// macOS accent, not Void's).
    func voidTextField() -> some View {
        modifier(AccentTextField())
    }
}

/// The system's prominent button draws a white label, unreadable on the pastel accents.
private struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    func makeBody(configuration: Configuration) -> some View {
        let large = controlSize == .large
        configuration.label
            .fontWeight(.medium)
            .foregroundStyle(Theme.onAccent)
            .padding(.horizontal, large ? 16 : 10)
            .frame(minHeight: large ? 34 : 22)
            .background(RoundedRectangle(cornerRadius: large ? 8 : 6, style: .continuous)
                .fill(Theme.accentFill)
                .brightness(configuration.isPressed ? -0.08 : 0))
            .contentShape(RoundedRectangle(cornerRadius: large ? 8 : 6, style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    func makeBody(configuration: Configuration) -> some View {
        let large = controlSize == .large
        configuration.label
            .fontWeight(.medium)
            .foregroundStyle(Theme.primaryText)
            .padding(.horizontal, large ? 16 : 10)
            .frame(minHeight: large ? 34 : 22)
            .background(RoundedRectangle(cornerRadius: large ? 8 : 6, style: .continuous)
                .fill(Theme.hover)
                .brightness(configuration.isPressed ? -0.05 : 0))
            .overlay(RoundedRectangle(cornerRadius: large ? 8 : 6, style: .continuous).strokeBorder(Theme.stroke))
            .contentShape(RoundedRectangle(cornerRadius: large ? 8 : 6, style: .continuous))
            .opacity(isEnabled ? 1 : 0.45)
    }
}

private struct AccentTextField: ViewModifier {
    @FocusState private var focused: Bool
    @Environment(\.controlSize) private var controlSize

    func body(content: Content) -> some View {
        let large = controlSize == .large
        content
            .textFieldStyle(.plain)
            .focused($focused)
            .focusEffectDisabled()
            .padding(.horizontal, large ? 10 : 7)
            .frame(minHeight: large ? 34 : 24)
            .background(RoundedRectangle(cornerRadius: large ? 8 : 6, style: .continuous).fill(Theme.hover))
            .overlay(RoundedRectangle(cornerRadius: large ? 8 : 6, style: .continuous)
                .strokeBorder(focused ? Theme.accent : Theme.stroke, lineWidth: focused ? 2 : 1))
            .animation(Theme.quick, value: focused)
    }
}

/// Switch drawn with Void's accent. The system switch follows the macOS accent color (and turns
/// grey in inactive windows), so it can't show the color chosen in Réglages.
struct AccentSwitchStyle: ToggleStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer(minLength: 12)
            Button { withAnimation(Theme.quick) { configuration.isOn.toggle() } } label: {
                Capsule()
                    .fill(configuration.isOn ? Theme.accent : Theme.switchOff)
                    .frame(width: 32, height: 18)
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(Theme.switchKnob)
                            .shadow(color: Theme.shadow.opacity(0.25), radius: 1, y: 0.5)
                            .padding(2)
                    }
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .opacity(isEnabled ? 1 : 0.4)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(configuration.isOn ? "activé" : "désactivé")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { configuration.isOn.toggle() }
    }
}

/// The Void Echo mark, as on the app icon: Void's eclipse — a dark disc over a luminous ring, lit
/// from the right — and three arcs going out from its lit side, fainter as they go: the echo.
/// The whole group (not the eclipse alone) is centered in the frame.
struct EchoLogo: View {
    var size: CGFloat = 64

    private static let arcs: [(radius: CGFloat, opacity: Double)] = [(1.42, 0.85), (1.84, 0.55), (2.26, 0.28)]

    var body: some View {
        let r = size / 2
        let stroke = r * 0.13
        let reach = r * Self.arcs.last!.radius + stroke / 2
        ZStack {
            ForEach(Self.arcs.indices, id: \.self) { index in
                let arc = Self.arcs[index]
                Circle()
                    .trim(from: 0, to: 0.25)
                    .rotation(.degrees(-45))
                    .stroke(Theme.logoEcho.opacity(arc.opacity), style: StrokeStyle(lineWidth: stroke, lineCap: .round))
                    .frame(width: 2 * r * arc.radius, height: 2 * r * arc.radius)
            }
            Circle()
                .fill(LinearGradient(colors: Theme.logoGradient.reversed(), startPoint: .leading, endPoint: .trailing))
                .shadow(color: Theme.logoGlow, radius: size * 0.12)
                .frame(width: size, height: size)
            Circle()
                .fill(Theme.logoCore)
                .frame(width: size * 0.86, height: size * 0.86)
                .offset(x: -r * 0.13)
        }
        // Centers the group: it spans from the eclipse's left edge to the outer arc.
        .offset(x: -(reach - r) / 2)
        .frame(width: r + reach, height: 2 * reach * sin(.pi / 4) + stroke)
        .accessibilityLabel("Void Echo")
    }
}

/// Small icon-only button used in the chrome.
struct ChromeButton: View {
    let symbol: String
    var help: String = ""
    var active: Bool = false
    var disabled: Bool = false
    var size: CGFloat = 13
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(active ? Theme.accent : Theme.secondaryText)
                .frame(width: 26, height: 26)
                .background(RoundedRectangle(cornerRadius: 7).fill(hovering && !disabled ? Theme.hover : .clear))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .help(help)
        .accessibilityLabel(help)
        .onHover { hovering = $0 }
        .animation(Theme.quick, value: hovering)
    }
}
