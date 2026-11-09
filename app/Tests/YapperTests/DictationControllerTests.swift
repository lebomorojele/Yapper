import XCTest
@testable import Yapper

final class DictationControllerTests: XCTestCase {
    @MainActor
    private func makeSUT() -> (
        sut: DictationController,
        audio: MockAudioEngine,
        transcriber: MockTranscriber,
        cleanup: MockTextCleanupProcessor,
        inserter: MockTextInserter
    ) {
        let mockAudio = MockAudioEngine()
        let mockTranscriber = MockTranscriber()
        let mockCleanup = MockTextCleanupProcessor()
        let mockInserter = MockTextInserter()
        let sut = DictationController(
            audioEngine: mockAudio,
            transcriber: mockTranscriber,
            textCleanupProcessor: mockCleanup,
            textInserter: mockInserter
        )
        return (sut, mockAudio, mockTranscriber, mockCleanup, mockInserter)
    }

    @MainActor
    func testDefaultDictationFlowCleansAndInsertsTranscript() {
        let originalSettings = SettingsManager.shared.settings
        SettingsManager.shared.update {
            $0.cleanupEnabled = true
            $0.modelCleanupWordThreshold = 2
        }
        defer { SettingsManager.shared.settings = originalSettings }

        let context = makeSUT()
        context.cleanup.output = "Final transcript."
        let expectation = expectation(description: "Session finished")

        context.sut.onSessionFinished = { result in
            XCTAssertEqual(result.transcript, "Final transcript.")
            XCTAssertEqual(result.insertionOutcome, .accessibility)
            expectation.fulfill()
        }

        context.sut.startRecording(
            configuration: RecordingSessionConfiguration(
                autoStopOnSilence: true,
                shouldInsertText: true
            )
        )
        XCTAssertTrue(context.audio.isRunning)

        context.sut.stopRecording()

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(context.cleanup.inputs, ["Final transcript."])
        XCTAssertEqual(context.inserter.insertedText, "Final transcript.")
    }

    @MainActor
    func testSilenceStopsDefaultDictation() {
        let originalSettings = SettingsManager.shared.settings
        SettingsManager.shared.update {
            $0.cleanupEnabled = true
            $0.modelCleanupWordThreshold = 99
        }
        defer { SettingsManager.shared.settings = originalSettings }

        let context = makeSUT()
        let expectation = expectation(description: "Session finished")
        context.sut.onSessionFinished = { _ in expectation.fulfill() }

        context.sut.startRecording(
            configuration: RecordingSessionConfiguration(
                autoStopOnSilence: true,
                shouldInsertText: true
            )
        )
        XCTAssertTrue(context.audio.silenceDetectionEnabled)

        context.audio.simulateSilence()

        waitForExpectations(timeout: 1.0)
        XCTAssertFalse(context.audio.isRunning)
        XCTAssertEqual(context.inserter.insertedText, "Final transcript.")
    }

    @MainActor
    func testStartRecordingAppliesAudioSettings() {
        let originalSettings = SettingsManager.shared.settings
        SettingsManager.shared.update {
            $0.silenceThreshold = 2.4
            $0.silenceDetectionEnabled = true
            $0.inputGain = 3.2
        }
        defer { SettingsManager.shared.settings = originalSettings }

        let context = makeSUT()
        context.sut.startRecording(
            configuration: RecordingSessionConfiguration(
                autoStopOnSilence: true,
                shouldInsertText: true
            )
        )

        XCTAssertEqual(context.audio.silenceThreshold, 2.4, accuracy: 0.001)
        XCTAssertTrue(context.audio.silenceDetectionEnabled)
        XCTAssertEqual(context.audio.inputGain, 3.2, accuracy: 0.001)
    }

    @MainActor
    func testCleanupDisabledInsertsRawTranscript() {
        let originalSettings = SettingsManager.shared.settings
        SettingsManager.shared.update {
            $0.cleanupEnabled = false
            $0.modelCleanupWordThreshold = 0
        }
        defer { SettingsManager.shared.settings = originalSettings }

        let context = makeSUT()
        context.cleanup.output = "Changed text."
        let expectation = expectation(description: "Session finished")
        context.sut.onSessionFinished = { _ in expectation.fulfill() }

        context.sut.startRecording(
            configuration: RecordingSessionConfiguration(
                autoStopOnSilence: true,
                shouldInsertText: true
            )
        )
        context.sut.stopRecording()

        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(context.cleanup.inputs.isEmpty)
        XCTAssertEqual(context.inserter.insertedText, "Final transcript")
    }

    @MainActor
    func testCleanupErrorFallsBackToRawTranscript() {
        let originalSettings = SettingsManager.shared.settings
        SettingsManager.shared.update {
            $0.cleanupEnabled = true
            $0.modelCleanupWordThreshold = 2
        }
        defer { SettingsManager.shared.settings = originalSettings }

        let context = makeSUT()
        context.cleanup.error = NSError(domain: "cleanup", code: 1)
        let expectation = expectation(description: "Session finished")
        context.sut.onSessionFinished = { result in
            XCTAssertEqual(result.transcript, "Final transcript.")
            expectation.fulfill()
        }

        context.sut.startRecording(
            configuration: RecordingSessionConfiguration(
                autoStopOnSilence: true,
                shouldInsertText: true
            )
        )
        context.sut.stopRecording()

        waitForExpectations(timeout: 1.0)
        XCTAssertEqual(context.inserter.insertedText, "Final transcript.")
    }

    @MainActor
    func testShortTranscriptUsesFastPathOnly() {
        let originalSettings = SettingsManager.shared.settings
        SettingsManager.shared.update {
            $0.cleanupEnabled = true
            $0.modelCleanupWordThreshold = 99
        }
        defer { SettingsManager.shared.settings = originalSettings }

        let context = makeSUT()
        context.transcriber.finalText = "hello there"
        let expectation = expectation(description: "Session finished")
        context.sut.onSessionFinished = { result in
            XCTAssertEqual(result.transcript, "Hello there.")
            expectation.fulfill()
        }

        context.sut.startRecording(
            configuration: RecordingSessionConfiguration(
                autoStopOnSilence: true,
                shouldInsertText: true
            )
        )
        context.sut.stopRecording()

        waitForExpectations(timeout: 1.0)
        XCTAssertTrue(context.cleanup.inputs.isEmpty)
        XCTAssertEqual(context.inserter.insertedText, "Hello there.")
    }

    @MainActor
    func testEmptyTranscriptDoesNotInsert() {
        let context = makeSUT()
        context.transcriber.finalText = "   "
        let expectation = expectation(description: "Session finished")
        context.sut.onSessionFinished = { result in
            XCTAssertEqual(result.transcript, "")
            XCTAssertNil(result.insertionOutcome)
            expectation.fulfill()
        }

        context.sut.startRecording(
            configuration: RecordingSessionConfiguration(
                autoStopOnSilence: true,
                shouldInsertText: true
            )
        )
        context.sut.stopRecording()

        waitForExpectations(timeout: 1.0)
        XCTAssertNil(context.inserter.insertedText)
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
    @MainActor
    func testMicrophoneStartFailureReportsErrorAndStopsSession() {
        let context = makeSUT()
        context.audio.startError = NSError(domain: "microphone", code: 1, userInfo: [NSLocalizedDescriptionKey: "Microphone disconnected"])
        let reported = expectation(description: "Microphone failure reported")
        context.sut.onError = { error in
            XCTAssertEqual(error.localizedDescription, "Microphone disconnected")
            reported.fulfill()
        }
        context.sut.startRecording(configuration: .init(autoStopOnSilence: true, shouldInsertText: true))
        waitForExpectations(timeout: 1)
        XCTAssertFalse(context.audio.isRunning)
        XCTAssertNil(context.inserter.insertedText)
    }

    @MainActor
    func testDiscardDuringCleanupNeverInsertsOldTranscript() async {
        let originalSettings = SettingsManager.shared.settings
        SettingsManager.shared.update { $0.modelCleanupWordThreshold = 0; $0.cleanupEnabled = true }
        defer { SettingsManager.shared.settings = originalSettings }
        let context = makeSUT()
        context.cleanup.delay = .milliseconds(100)
        let controller = context.sut
        context.cleanup.onClean = {
            DispatchQueue.main.async { controller.discardRecording() }
        }
        context.sut.startRecording(configuration: .init(autoStopOnSilence: true, shouldInsertText: true))
        context.sut.stopRecording()
        try? await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(context.cleanup.inputs, ["Final transcript."])
        XCTAssertNil(context.inserter.insertedText)
    }

    @MainActor
    func testSessionCanDisableSilenceDetection() {
        let context = makeSUT()
        context.sut.startRecording(configuration: .init(autoStopOnSilence: false, shouldInsertText: true))
        XCTAssertFalse(context.audio.silenceDetectionEnabled)
        context.audio.simulateSilence()
        XCTAssertTrue(context.audio.isRunning)
        context.sut.discardRecording()
    }

}
