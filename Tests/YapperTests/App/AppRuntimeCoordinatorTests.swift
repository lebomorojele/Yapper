import XCTest
@testable import Yapper

@MainActor
final class AppRuntimeCoordinatorTests: XCTestCase {
    private func makeSUT() -> (
        sut: AppRuntimeCoordinator,
        dictation: MockDictationController,
        hotkeys: MockHotkeyManager,
        permissions: MockPermissionManager
    ) {
        let dictation = MockDictationController()
        let hotkeys = MockHotkeyManager()
        let permissions = MockPermissionManager()
        let sut = AppRuntimeCoordinator(
            dictationController: dictation,
            hotkeyManager: hotkeys,
            permissionManager: permissions
        )
        return (sut, dictation, hotkeys, permissions)
    }

    private func markModelReady(_ context: (
        sut: AppRuntimeCoordinator,
        dictation: MockDictationController,
        hotkeys: MockHotkeyManager,
        permissions: MockPermissionManager
    )) async {
        context.dictation.onModelLoaded?()
        await Task.yield()
    }

    func testStartLoadsModelRefreshesPermissionsAndStartsHotkeys() async {
        let context = makeSUT()

        context.sut.start()
        await markModelReady(context)

        XCTAssertEqual(context.hotkeys.startCallCount, 1)
        XCTAssertEqual(context.hotkeys.permissionSnapshots.last, context.permissions.currentSnapshot)
        XCTAssertTrue(context.sut.state.modelReady)
        XCTAssertEqual(context.sut.state.recordingPhase, .idle)
    }

    func testSingleTapStartsDictationSession() async {
        let context = makeSUT()
        context.sut.start()
        await markModelReady(context)

        context.sut.handleGesture(.singleTap)

        XCTAssertEqual(context.dictation.startConfigurations.count, 1)
        XCTAssertTrue(context.dictation.startConfigurations.first?.autoStopOnSilence == true)
        XCTAssertTrue(context.dictation.startConfigurations.first?.shouldInsertText == true)
        XCTAssertEqual(context.sut.state.recordingPhase, .recording)
        XCTAssertNotNil(context.sut.state.session)
    }

    func testSecondSingleTapStopsActiveDictation() async {
        let context = makeSUT()
        context.sut.start()
        await markModelReady(context)
        context.sut.handleGesture(.singleTap)

        context.sut.handleGesture(.singleTap)
        await Task.yield()

        XCTAssertEqual(context.dictation.stopCallCount, 1)
        XCTAssertEqual(context.sut.state.recordingPhase, .processing)
    }

    func testRecordingStoppedMovesToProcessing() async {
        let context = makeSUT()
        context.sut.start()
        await markModelReady(context)
        context.sut.handleGesture(.singleTap)

        context.dictation.onRecordingStopped?()
        await Task.yield()

        XCTAssertEqual(context.sut.state.recordingPhase, .processing)
    }

    func testFinishedSessionMovesToCompletedAndClearsSession() async {
        let context = makeSUT()
        context.sut.start()
        await markModelReady(context)
        context.sut.handleGesture(.singleTap)

        guard let session = context.sut.state.session else {
            return XCTFail("Expected active session")
        }

        context.dictation.onSessionFinished?(
            RecordingSessionResult(
                session: session,
                transcript: "Dictated text",
                insertionOutcome: .accessibility
            )
        )
        await Task.yield()

        XCTAssertEqual(context.sut.state.recordingPhase, .completed(.accessibility))
        XCTAssertNil(context.sut.state.session)
        XCTAssertNil(context.sut.state.recordingStartTime)
    }

    func testTapDuringProcessingQueuesImmediateRestartAfterFinish() async {
        let context = makeSUT()
        context.sut.start()
        await markModelReady(context)
        context.sut.handleGesture(.singleTap)

        guard let session = context.sut.state.session else {
            return XCTFail("Expected active session")
        }

        context.sut.handleGesture(.singleTap)
        XCTAssertEqual(context.sut.state.recordingPhase, .processing)

        context.sut.handleGesture(.singleTap)
        await Task.yield()

        context.dictation.onSessionFinished?(
            RecordingSessionResult(
                session: session,
                transcript: "Dictated text",
                insertionOutcome: .accessibility
            )
        )
        await Task.yield()

        XCTAssertEqual(context.dictation.startConfigurations.count, 2)
        XCTAssertEqual(context.sut.state.recordingPhase, .recording)
        XCTAssertNotNil(context.sut.state.session)
    }

    func testFailureCleansUpActiveSessionAndMovesToFailedState() async {
        let context = makeSUT()
        context.sut.start()
        await markModelReady(context)
        context.sut.handleGesture(.singleTap)
        XCTAssertNotNil(context.sut.state.session)

        context.dictation.onError?(NSError(domain: "test", code: 99, userInfo: [NSLocalizedDescriptionKey: "boom"]))
        await Task.yield()

        XCTAssertEqual(context.dictation.discardCallCount, 1)
        XCTAssertNil(context.sut.state.session)
        XCTAssertNil(context.sut.state.recordingStartTime)
        XCTAssertEqual(context.sut.state.recordingPhase, .failed("boom"))
    }
}
