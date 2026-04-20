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
        let expectation = expectation(description: "Session finished")

        context.sut.onSessionFinished = { result in
            XCTAssertEqual(result.transcript, "Final transcript")
            XCTAssertEqual(result.insertionOutcome, .accessibility)
            XCTAssertEqual(result.session.purpose, .dictation)
            expectation.fulfill()
        }

        context.sut.startRecording(
            configuration: RecordingSessionConfiguration(
                purpose: .dictation,
                autoStopOnSilence: true,
                shouldInsertText: true
            )
        )
        XCTAssertTrue(context.audio.isRunning)

        context.sut.stopRecording()

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(context.inserter.insertedText, "Final transcript")
    }

    @MainActor
    func testSilenceStopsDefaultDictation() {
        let context = makeSUT()
        context.sut.startRecording(
            configuration: RecordingSessionConfiguration(
                purpose: .dictation,
                autoStopOnSilence: true,
                shouldInsertText: true
            )
        )
        XCTAssertTrue(context.audio.silenceDetectionEnabled)

        context.audio.simulateSilence()

        XCTAssertFalse(context.audio.isRunning)
        XCTAssertEqual(context.inserter.insertedText, "Final transcript")
    }

    @MainActor
    func testMeetingStyleRecordingIgnoresSilence() {
        let context = makeSUT()
        context.sut.startRecording(
            configuration: RecordingSessionConfiguration(
                purpose: .meeting,
                autoStopOnSilence: false,
                shouldInsertText: false
            )
        )
        XCTAssertFalse(context.audio.silenceDetectionEnabled)

        context.audio.simulateSilence()

        XCTAssertTrue(context.audio.isRunning)
        XCTAssertNil(context.inserter.insertedText)
    }

    @MainActor
    func testMeetingRecordingFinishesWithoutInsertion() {
        let context = makeSUT()
        let expectation = expectation(description: "Meeting session finished")

        context.sut.onSessionFinished = { result in
            XCTAssertEqual(result.session.purpose, .meeting)
            XCTAssertEqual(result.transcript, "Final transcript")
            XCTAssertNil(result.insertionOutcome)
            expectation.fulfill()
        }

        context.sut.startRecording(
            configuration: RecordingSessionConfiguration(
                purpose: .meeting,
                autoStopOnSilence: false,
                shouldInsertText: false
            )
        )

        context.sut.stopRecording()

        waitForExpectations(timeout: 1.0)
        XCTAssertNil(context.inserter.insertedText)
    }

    @MainActor
    func testSmartModeCancelInsertsRawTranscript() {
        let context = makeSUT()
        let expectation = expectation(description: "Smart cancel finishes")

        context.sut.onSessionFinished = { result in
            XCTAssertEqual(result.session.purpose, .smart)
            XCTAssertEqual(result.transcript, "Final transcript")
            XCTAssertEqual(result.insertionOutcome, .accessibility)
            expectation.fulfill()
        }

        context.sut.startRecording(
            configuration: RecordingSessionConfiguration(
                purpose: .smart,
                autoStopOnSilence: true,
                shouldInsertText: false
            )
        )
        context.sut.stopRecording()
        context.sut.handleSmartModeSelection(.cancel)

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(context.inserter.insertedText, "Final transcript")
    }

    @MainActor
    func testDiscardRecordingStopsWithoutFinishingSession() {
        let context = makeSUT()
        let finishExpectation = expectation(description: "Session should not finish")
        finishExpectation.isInverted = true
        context.sut.onSessionFinished = { _ in
            finishExpectation.fulfill()
        }

        context.sut.startRecording(
            configuration: RecordingSessionConfiguration(
                purpose: .dictation,
                autoStopOnSilence: true,
                shouldInsertText: true
            )
        )
        XCTAssertTrue(context.audio.isRunning)

        context.sut.discardRecording()

        waitForExpectations(timeout: 0.1)
        XCTAssertFalse(context.audio.isRunning)
        XCTAssertNil(context.inserter.insertedText)
    }
}
