import Foundation

/// A Jitsi Meet server, as typed in Réglages → Serveur Jitsi: "meet.jit.si", "visio.exemple.fr",
/// "https://visio.exemple.fr:8443", or with a path for a server that serves its rooms below one
/// (JaaS: "8x8.vc/vpaas-magic-cookie-…"). Always HTTPS: the camera and the microphone are only
/// given to secure pages.
struct JitsiServer: Hashable, Codable {
    /// The public Jitsi service, used until another server is set. The ONLY place where a server
    /// address is written in Void Echo's code.
    static let defaultAddress = "meet.jit.si"

    /// "https://host[:port][/path]", without a trailing slash.
    let baseURL: URL

    static let `default` = JitsiServer(address: defaultAddress)!

    /// nil when `address` can't be a server address (spaces, no host…).
    init?(address: String) {
        var text = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !text.contains(where: \.isWhitespace) else { return nil }
        if text.lowercased().hasPrefix("http://") { text = "https://" + text.dropFirst(7) }
        if !text.lowercased().hasPrefix("https://") { text = "https://" + text }
        guard var components = URLComponents(string: text), let host = components.host?.lowercased(), !host.isEmpty,
              host.contains(".") || host == "localhost" else { return nil }
        components.scheme = "https"
        components.host = host
        components.query = nil
        components.fragment = nil
        components.user = nil
        components.password = nil
        while components.path.hasSuffix("/") { components.path.removeLast() }
        guard let url = components.url else { return nil }
        baseURL = url
    }

    var host: String { baseURL.host() ?? "" }

    /// As shown to people: "meet.jit.si", "visio.exemple.fr/equipe".
    var displayName: String {
        var text = host
        if let port = baseURL.port { text += ":\(port)" }
        return text + baseURL.path(percentEncoded: false)
    }

    var isDefault: Bool { self == .default }

    func url(forRoom room: String) -> URL {
        baseURL.appending(path: room)
    }
}

/// A meeting: a room on a server. Its link is what people share.
struct MeetingRoom: Hashable, Codable, Identifiable {
    let server: JitsiServer
    /// As typed or generated; Jitsi itself compares room names without case.
    let name: String

    var id: String { url.absoluteString.lowercased() }
    var url: URL { server.url(forRoom: name) }
    /// The link as people paste it: "https://meet.jit.si/brume-lente-orage-7k3q9x".
    var link: String { url.absoluteString }

    /// "brume-lente-orage-7k3q9x" → "Brume lente orage · 7k3q9x"; other names as they are.
    var displayName: String {
        let parts = name.split(separator: "-")
        guard parts.count == RoomNameGenerator.wordCount + 1,
              parts.last?.count == RoomNameGenerator.suffixLength else { return name.removingPercentEncoding ?? name }
        let words = parts.dropLast().joined(separator: " ")
        return words.prefix(1).uppercased() + words.dropFirst() + " · " + parts.last!
    }
}

/// What "Rejoindre" accepts: a full link (of the configured server or of any other Jitsi server),
/// a link without "https://", or a room name alone, opened on the configured server.
enum MeetingLinkParser {
    enum Failure: Error, Equatable {
        case empty, invalidName, noRoomInLink
    }

    static func parse(_ input: String, defaultServer: JitsiServer) -> Result<MeetingRoom, Failure> {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return .failure(.empty) }

        // A room name alone: letters, digits, "-", "_" and ".", no "/".
        if !text.contains("/"), !text.contains(":") {
            guard isValidRoomName(text) else { return .failure(.invalidName) }
            return .success(MeetingRoom(server: defaultServer, name: text))
        }

        var linkText = text
        if !linkText.lowercased().hasPrefix("http://") && !linkText.lowercased().hasPrefix("https://") {
            linkText = "https://" + linkText
        }
        guard let components = URLComponents(string: linkText), let host = components.host?.lowercased(), !host.isEmpty else {
            return .failure(.invalidName)
        }
        let segments = components.path.split(separator: "/").map(String.init)
        guard let room = segments.last.flatMap({ $0.removingPercentEncoding }), isValidRoomName(room) else {
            return .failure(.noRoomInLink)
        }

        // A link of the configured server keeps its exact address (port, path of the tenant).
        let prefix = segments.dropLast().joined(separator: "/")
        let defaultPath = defaultServer.baseURL.path(percentEncoded: false).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if host == defaultServer.host, components.port == defaultServer.baseURL.port, prefix == defaultPath {
            return .success(MeetingRoom(server: defaultServer, name: room))
        }
        var serverAddress = host
        if let port = components.port { serverAddress += ":\(port)" }
        if !prefix.isEmpty { serverAddress += "/" + prefix }
        guard let server = JitsiServer(address: serverAddress) else { return .failure(.invalidName) }
        return .success(MeetingRoom(server: server, name: room))
    }

    /// Jitsi accepts most characters, but a name that survives being pasted anywhere is safer.
    static func isValidRoomName(_ name: String) -> Bool {
        guard (1...120).contains(name.count) else { return false }
        return name.unicodeScalars.allSatisfy { CharacterSet.alphanumerics.contains($0) || "-_.".unicodeScalars.contains($0) }
            && !name.hasPrefix(".")
    }

    static func message(for failure: Failure) -> String {
        switch failure {
        case .empty: "Collez un lien de réunion ou tapez le nom d'une salle."
        case .invalidName: "Ce n'est ni un lien ni un nom de salle valide (lettres, chiffres, tirets)."
        case .noRoomInLink: "Ce lien ne contient pas de nom de salle valide (lettres, chiffres, tirets)."
        }
    }
}

/// Names of new rooms: three short French words and a random suffix — "brume-lente-orage-7k3q9x".
/// Easy to read aloud, hard to guess: 128 × 128 × 128 words and 31⁶ suffixes, about 50 bits drawn
/// from the system's secure generator. No accents, so the link stays the same once pasted anywhere.
enum RoomNameGenerator {
    static let wordCount = 3
    static let suffixLength = 6

    static func make() -> String {
        var generator = SystemRandomNumberGenerator()
        let picked = [nouns, adjectives, nouns].map { $0.randomElement(using: &generator)! }
        let suffix = String((0..<suffixLength).map { _ in alphabet.randomElement(using: &generator)! })
        return (picked + [suffix]).joined(separator: "-")
    }

    /// Without 0/o, 1/l/i: nothing to confuse when the name is read aloud or copied by hand.
    private static let alphabet = Array("23456789abcdefghjkmnpqrstuvwxyz")

    private static let nouns = [
        "abri", "acier", "aigle", "algue", "ambre", "ancre", "arbre", "arche", "argile", "astre",
        "aube", "aurore", "avril", "baie", "balise", "barque", "bassin", "bleuet", "bois", "bouleau",
        "boussole", "brise", "brume", "cadran", "calme", "canal", "cap", "cedre", "cerf", "chene",
        "ciel", "cirque", "col", "comete", "corail", "cote", "crete", "cristal", "cygne", "dune",
        "eclat", "ecume", "erable", "escale", "etang", "etoile", "falaise", "faon", "fjord", "fleuve",
        "foret", "fougere", "galet", "givre", "glacier", "grive", "havre", "heron", "horizon", "ile",
        "iris", "jade", "jardin", "lagune", "lande", "lanterne", "lichen", "lierre", "lin", "loutre",
        "lueur", "lune", "lynx", "marais", "maree", "merle", "meteore", "mistral", "mousse", "nacre",
        "neige", "nuage", "oasis", "ocean", "olivier", "ombre", "onde", "opale", "orage", "orme",
        "pente", "phare", "pin", "plaine", "pluie", "port", "prairie", "quartz", "rameau", "recif",
        "renard", "riviere", "roche", "rosee", "ruisseau", "sable", "saule", "sentier", "sillage", "silex",
        "soleil", "source", "sommet", "tilleul", "torrent", "toundra", "tourbe", "val", "vague", "vallon",
        "vent", "verger", "voile", "volcan", "zenith", "zephyr", "delta", "fjell",
    ]

    private static let adjectives = [
        "agile", "aimable", "alerte", "ample", "ardent", "argente", "austral", "azur", "bleu", "boreal",
        "brave", "brillant", "brun", "calme", "candide", "celeste", "clair", "concis", "cuivre", "dense",
        "discret", "dore", "doux", "droit", "eclatant", "egal", "eloigne", "epais", "fauve", "fertile",
        "fidele", "fier", "fin", "fluide", "frais", "franc", "furtif", "gai", "gele", "grand",
        "gris", "habile", "haut", "heureux", "immense", "indigo", "intense", "juste", "large", "leger",
        "lent", "libre", "limpide", "lisse", "lointain", "loyal", "lucide", "lumineux", "mauve", "mobile",
        "modeste", "mouvant", "naif", "natif", "net", "neuf", "noble", "nocturne", "nomade", "obscur",
        "ocre", "opaque", "ouvert", "pale", "paisible", "patient", "perle", "placide", "plein", "poli",
        "precis", "profond", "prompt", "pur", "rapide", "rare", "ravi", "rebelle", "robuste", "rond",
        "rose", "roux", "rustique", "sage", "sauvage", "secret", "serein", "sincere", "sobre", "solaire",
        "solide", "sombre", "souple", "stable", "subtil", "sur", "tenace", "tendre", "tiede", "timide",
        "tranquille", "vaste", "velours", "vermeil", "vert", "vif", "vigilant", "violet", "vivace", "volage",
        "zele", "boise", "brumeux", "ombre", "polaire", "radieux", "sable", "lunaire",
    ]
}
