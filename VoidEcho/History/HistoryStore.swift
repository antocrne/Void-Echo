import Foundation
import Observation

/// A meeting joined from this Mac.
struct HistoryEntry: Codable, Identifiable, Hashable {
    let room: MeetingRoom
    /// Last time it was joined.
    var date: Date

    var id: String { room.id }
}

/// Recent meetings, most recent first: a JSON file in Void Echo's container (Application
/// Support). Joining a meeting again moves it to the top. Nothing leaves the Mac.
@MainActor @Observable
final class HistoryStore {
    static let shared = HistoryStore()
    static let limit = 50

    private(set) var entries: [HistoryEntry] = []
    @ObservationIgnored private let fileURL: URL

    init(fileURL: URL = HistoryStore.defaultFileURL) {
        self.fileURL = fileURL
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: fileURL),
           let saved = try? decoder.decode([HistoryEntry].self, from: data) {
            entries = saved.sorted { $0.date > $1.date }
        }
    }

    nonisolated static var defaultFileURL: URL {
        let folder = URL.applicationSupportDirectory.appending(path: "Void Echo", directoryHint: .isDirectory)
        return folder.appending(path: "history.json")
    }

    func record(_ room: MeetingRoom, at date: Date = .now) {
        entries.removeAll { $0.id == room.id }
        entries.insert(HistoryEntry(room: room, date: date), at: 0)
        if entries.count > Self.limit { entries.removeLast(entries.count - Self.limit) }
        save()
    }

    func remove(_ entry: HistoryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    func clear() {
        entries = []
        save()
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(entries).write(to: fileURL, options: .atomic)
        } catch {
            NSLog("Void Echo: historique non enregistré (\(error.localizedDescription))")
        }
    }
}
