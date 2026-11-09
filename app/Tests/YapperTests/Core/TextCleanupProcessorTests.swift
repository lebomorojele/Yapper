import XCTest
import Darwin
@testable import Yapper

final class TextCleanupProcessorTests: XCTestCase {
    func testHeuristicCleanupTrimsCapitalizesAndAddsPeriod() async throws {
        let sut = HeuristicTextCleanupProcessor()

        let output = try await sut.clean(text: "  hello   from yapper  ")

        XCTAssertEqual(output, "Hello from yapper.")
    }

    func testLlamaCleanupReportsMissingBundledResources() async {
        let sut = LlamaCppTextCleanupProcessor(executableURL: nil, modelURL: nil, modelURLProvider: nil)

        do {
            _ = try await sut.clean(text: "hello")
            XCTFail("Expected missing resources error")
        } catch TextCleanupError.missingLocalInferenceResources {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFallbackCleanupUsesHeuristicWhenPrimaryUnavailable() async throws {
        let sut = FallbackTextCleanupProcessor(
            primary: LlamaCppTextCleanupProcessor(executableURL: nil, modelURL: nil, modelURLProvider: nil),
            fallback: HeuristicTextCleanupProcessor()
        )

        let output = try await sut.clean(text: "hello there")

        XCTAssertEqual(output, "Hello there.")
    }

    func testLlamaCleanupExtractsStrictJsonPayload() throws {
        let output = try LlamaCppTextCleanupProcessor.extractCleanedText(
            from: #"{"text":"So it looks like it's working now. That's great!"}"#
        )

        XCTAssertEqual(output, "So it looks like it's working now. That's great!")
    }

    func testLlamaCleanupExtractsJsonFromNoisyOutput() throws {
        let output = try LlamaCppTextCleanupProcessor.extractCleanedText(
            from: """
            Explanation:
            {"text":"Hello there."}
            """
        )

        XCTAssertEqual(output, "Hello there.")
    }
    func testCancellingCleanupTerminatesItsProcess() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let pidFile = directory.appendingPathComponent("pid")
        let executable = directory.appendingPathComponent("cleanup.sh")
        let escapedPath = pidFile.path.replacingOccurrences(of: "'", with: "'\''")
        let script = """
        #!/bin/sh
        printf '%s\n' "$$" > '\(escapedPath)'
        exec /bin/sleep 60
        """
        try script.write(to: executable, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)
        let processor = LlamaCppTextCleanupProcessor(executableURL: executable, modelURL: directory.appendingPathComponent("unused.gguf"), timeout: 60)
        let task = Task { try await processor.clean(text: "hello") }
        defer { task.cancel() }
        var pid: Int32?
        for _ in 0..<100 {
            if let raw = try? String(contentsOf: pidFile, encoding: .utf8),
               let value = Int32(raw.trimmingCharacters(in: .whitespacesAndNewlines)) {
                pid = value
                break
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        let childPID = try XCTUnwrap(pid)
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Expected cleanup cancellation")
        } catch is CancellationError {}
        XCTAssertNotEqual(kill(childPID, 0), 0, "Cancelled cleanup left its child process running")
    }

}
