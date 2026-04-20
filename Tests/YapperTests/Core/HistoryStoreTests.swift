import XCTest
@testable import Yapper

final class HistoryStoreTests: XCTestCase {
    func testSaveAndLoadEntriesRoundTripsPersistedHistory() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = HistoryStore(baseDirectory: directory)
        let entry = HistoryEntry(
            kind: .dictation,
            transcript: "Hello world",
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            duration: 12,
            insertionOutcome: .accessibility
        )

        try store.save(entry: entry)
        let loaded = try store.loadEntries()

        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.transcript, "Hello world")
        XCTAssertEqual(loaded.first?.kind, .dictation)
        XCTAssertEqual(loaded.first?.insertionOutcome, .accessibility)
    }

    func testUpdateReplacesExistingEntry() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = HistoryStore(baseDirectory: directory)
        var entry = HistoryEntry(
            id: UUID(),
            kind: .meeting,
            transcript: "Initial",
            createdAt: Date(timeIntervalSince1970: 1_700_000_100),
            duration: 20,
            insertionOutcome: nil
        )

        try store.save(entry: entry)
        entry.transcript = "Updated transcript"
        entry.enrichment.summary = "Short summary"
        try store.update(entry: entry)

        let loaded = try store.loadEntries()
        XCTAssertEqual(loaded.count, 1)
        XCTAssertEqual(loaded.first?.transcript, "Updated transcript")
        XCTAssertEqual(loaded.first?.enrichment.summary, "Short summary")
    }

    func testTranscriptExporterUsesMeetingFolderForMeetings() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var settings = Settings.default
        settings.saveTranscripts = true
        settings.saveLocation = root.path
        let entry = HistoryEntry(
            kind: .meeting,
            transcript: "Meeting body",
            createdAt: Date(timeIntervalSince1970: 1_700_000_200),
            duration: 33,
            insertionOutcome: nil
        )

        let exportedPath = try XCTUnwrap(try TranscriptExporter.exportTranscript(entry, settings: settings))

        XCTAssertTrue(exportedPath.contains("Yapper Meetings"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportedPath))
    }

    func testTranscriptExporterUsesDictationFolderForDictation() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var settings = Settings.default
        settings.saveTranscripts = true
        settings.saveLocation = root.path
        let entry = HistoryEntry(
            kind: .dictation,
            transcript: "Dictation body",
            createdAt: Date(timeIntervalSince1970: 1_700_000_300),
            duration: 9,
            insertionOutcome: .clipboard
        )

        let exportedPath = try XCTUnwrap(try TranscriptExporter.exportTranscript(entry, settings: settings))

        XCTAssertTrue(exportedPath.contains("Yapper Dictation"))
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportedPath))
    }

    func testTranscriptExporterReturnsNilWhenDisabled() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        var settings = Settings.default
        settings.saveTranscripts = false
        settings.saveLocation = root.path
        let entry = HistoryEntry(
            kind: .meeting,
            transcript: "Meeting body",
            createdAt: Date(timeIntervalSince1970: 1_700_000_400),
            duration: 15,
            insertionOutcome: nil
        )

        let exportedPath = try TranscriptExporter.exportTranscript(entry, settings: settings)

        XCTAssertNil(exportedPath)
    }
}
