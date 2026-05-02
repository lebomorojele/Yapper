import XCTest
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
}
