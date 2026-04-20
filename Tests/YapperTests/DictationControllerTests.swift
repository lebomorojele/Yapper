import XCTest
@testable import Yapper

final class DictationControllerTests: XCTestCase {
    @MainActor
    private func makeSUT() -> (
        sut: DictationController,
        audio: MockAudioEngine,
        transcriber: MockTranscriber,
        inserter: MockTextInserter,
        llm: MockLLMProcessor
    ) {
        let mockAudio = MockAudioEngine()
        let mockTranscriber = MockTranscriber()
        let mockInserter = MockTextInserter()
        let mockLLM = MockLLMProcessor()
        let sut = DictationController(
            audioEngine: mockAudio,
            transcriber: mockTranscriber,
            llmProcessor: mockLLM,
            textInserter: mockInserter
        )
        return (sut, mockAudio, mockTranscriber, mockInserter, mockLLM)
    }

    @MainActor
    func testDefaultDictationFlowInsertsTranscript() {
        let context = makeSUT()
        let expectation = expectation(description: "Final transcript emitted")

        context.sut.onFinalTranscript = { text, outcome in
            XCTAssertEqual(text, "Final transcript")
            XCTAssertEqual(outcome, .accessibility)
            expectation.fulfill()
        }

        context.sut.startRecording(smartMode: false)
        XCTAssertTrue(context.audio.isRunning)

        context.sut.stopRecording()

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(context.inserter.insertedText, "Final transcript")
    }

    @MainActor
    func testSilenceStopsDefaultDictation() {
        let context = makeSUT()
        context.sut.startRecording(smartMode: false, autoStopOnSilence: true)
        XCTAssertTrue(context.audio.silenceDetectionEnabled)

        context.audio.simulateSilence()

        XCTAssertFalse(context.audio.isRunning)
        XCTAssertEqual(context.inserter.insertedText, "Final transcript")
    }

    @MainActor
    func testMeetingStyleRecordingIgnoresSilence() {
        let context = makeSUT()
        context.sut.startRecording(smartMode: false, autoStopOnSilence: false)
        XCTAssertFalse(context.audio.silenceDetectionEnabled)

        context.audio.simulateSilence()

        XCTAssertTrue(context.audio.isRunning)
        XCTAssertNil(context.inserter.insertedText)
    }
}
