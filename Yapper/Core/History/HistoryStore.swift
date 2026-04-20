import Foundation

final class HistoryStore: HistoryStoreProtocol, @unchecked Sendable {
    static let shared = HistoryStore()

    private let fileManager = FileManager.default
    private let lock = NSLock()
    private let fileURL: URL

    init(baseDirectory: URL? = nil) {
        let directory: URL
        if let baseDirectory {
            directory = baseDirectory
        } else {
            let appSupport = try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            directory = (appSupport ?? URL(fileURLWithPath: NSTemporaryDirectory()))
                .appendingPathComponent("Yapper", isDirectory: true)
                .appendingPathComponent("History", isDirectory: true)
        }

        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        self.fileURL = directory.appendingPathComponent("history.json")
    }

    func loadEntries() throws -> [HistoryEntry] {
        lock.lock()
        defer { lock.unlock() }

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.pretty.decode([HistoryEntry].self, from: data)
    }

    func save(entry: HistoryEntry) throws {
        lock.lock()
        defer { lock.unlock() }

        var entries = try readEntriesLocked()
        entries.removeAll { $0.id == entry.id }
        entries.insert(entry, at: 0)
        try writeEntriesLocked(entries)
    }

    func update(entry: HistoryEntry) throws {
        try save(entry: entry)
    }

    private func readEntriesLocked() throws -> [HistoryEntry] {
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder.pretty.decode([HistoryEntry].self, from: data)
    }

    private func writeEntriesLocked(_ entries: [HistoryEntry]) throws {
        let data = try JSONEncoder.pretty.encode(entries)
        try data.write(to: fileURL, options: .atomic)
    }
}

enum TranscriptExporter {
    static func exportTranscript(_ entry: HistoryEntry, settings: Settings) throws -> String? {
        guard settings.saveTranscripts else { return nil }

        let basePath = settings.saveLocation?.isEmpty == false
            ? settings.saveLocation!
            : NSHomeDirectory() + "/Documents"
        let folderName = entry.kind == .meeting ? "Yapper Meetings" : "Yapper Dictation"
        let filePrefix = entry.kind == .meeting ? "meeting" : "dictation"
        let directory = URL(fileURLWithPath: basePath, isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let formatter = ISO8601DateFormatter()
        let fileName = "\(filePrefix)-\(formatter.string(from: entry.createdAt)).txt"
            .replacingOccurrences(of: ":", with: "-")
        let fileURL = directory.appendingPathComponent(fileName)
        try entry.transcript.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL.path
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }
}

private extension JSONDecoder {
    static var pretty: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}
