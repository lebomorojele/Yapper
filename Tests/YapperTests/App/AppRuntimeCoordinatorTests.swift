import XCTest
@testable import Yapper

@MainActor
final class AppRuntimeCoordinatorTests: XCTestCase {
    private func makeSUT() -> (
        sut: AppRuntimeCoordinator,
        dictation: MockDictationController,
        hotkeys: MockHotkeyManager,
        permissions: MockPermissionManager,
        history: MockHistoryStore
    ) {
        let dictation = MockDictationController()
        let hotkeys = MockHotkeyManager()
        let permissions = MockPermissionManager()
        let history = MockHistoryStore()
        let sut = AppRuntimeCoordinator(
            dictationController: dictation,
            hotkeyManager: hotkeys,
            permissionManager: permissions,
            historyStore: history
        )
        return (sut, dictation, hotkeys, permissions, history)
    }

    private func markModelReady(_ context: (
        sut: AppRuntimeCoordinator,
        dictation: MockDictationController,
        hotkeys: MockHotkeyManager,
        permissions: MockPermissionManager,
        history: MockHistoryStore
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
    }

    func testSingleTapStartsDictationSession() async {
        let context = makeSUT()
        context.sut.start()
        await markModelReady(context)

        context.sut.handleGesture(.singleTap)

        XCTAssertEqual(context.dictation.startConfigurations.count, 1)
        XCTAssertEqual(context.dictation.startConfigurations.first?.purpose, .dictation)
        XCTAssertEqual(context.sut.state.recordingPhase, .recording)
        XCTAssertEqual(context.sut.state.session?.purpose, .dictation)
    }

    func testDoubleTapDuringDictationCancelsAndCleansUpSession() async {
        let context = makeSUT()
        context.sut.start()
        await markModelReady(context)
        context.sut.handleGesture(.singleTap)

        context.sut.handleGesture(.doubleTap)

        XCTAssertEqual(context.dictation.discardCallCount, 1)
        XCTAssertNil(context.sut.state.session)
        XCTAssertNil(context.sut.state.recordingStartTime)
        XCTAssertEqual(context.sut.state.recordingPhase, .idle)
    }

    func testHoldStartDuringDictationCancelsAndResetsToIdle() async {
        let context = makeSUT()
        context.sut.start()
        await markModelReady(context)
        context.sut.handleGesture(.singleTap)

        context.sut.handleGesture(.holdStart)

        XCTAssertEqual(context.dictation.discardCallCount, 1)
        XCTAssertEqual(context.sut.state.recordingPhase, .idle)
        XCTAssertNil(context.sut.state.session)
    }

    func testSmartRecordingStopMovesToSelectionState() async {
        let context = makeSUT()
        context.sut.start()
        await markModelReady(context)
        context.sut.handleGesture(.doubleTap)

        XCTAssertEqual(context.sut.state.recordingPhase, .recordingSmart)

        context.dictation.onRecordingStopped?()
        await Task.yield()

        XCTAssertEqual(context.sut.state.recordingPhase, .selectingSmartMode)
    }

    func testSelectSmartModeForwardsToDictationController() async {
        let context = makeSUT()
        context.sut.start()
        await markModelReady(context)
        context.sut.handleGesture(.doubleTap)
        context.dictation.onRecordingStopped?()
        await Task.yield()

        context.sut.selectSmartMode(.email)

        XCTAssertEqual(context.dictation.selectedOptions, [.email])
        XCTAssertEqual(context.sut.state.recordingPhase, .processing)
    }

    func testMeetingSessionFinishPersistsHistoryEntryWithoutInsertionOutcome() async {
        let context = makeSUT()
        context.sut.start()
        await markModelReady(context)
        context.sut.handleGesture(.holdStart)

        let session = context.sut.state.session
        XCTAssertEqual(session?.purpose, .meeting)
        guard let session else {
            return XCTFail("Expected active meeting session")
        }

        context.dictation.onSessionFinished?(
            RecordingSessionResult(
                session: session,
                transcript: "Meeting transcript",
                insertionOutcome: nil
            )
        )
        await Task.yield()

        XCTAssertEqual(context.history.entries.count, 1)
        XCTAssertEqual(context.history.entries.first?.kind, .meeting)
        XCTAssertEqual(context.history.entries.first?.transcript, "Meeting transcript")
        XCTAssertEqual(context.sut.state.recordingPhase, .completed(nil))
        XCTAssertNil(context.sut.state.session)
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
