import XCTest
@testable import Yapper

private final class MockHotkeyEventTapController: HotkeyEventTapControlling {
    var installShouldSucceed = true
    var installCount = 0
    var uninstallCount = 0
    var enabledValues: [Bool] = []

    func install(callback: CGEventTapCallBack, userInfo: UnsafeMutableRawPointer?) -> Bool {
        installCount += 1
        return installShouldSucceed
    }

    func setEnabled(_ enabled: Bool) {
        enabledValues.append(enabled)
    }

    func uninstall() {
        uninstallCount += 1
    }
}

final class HotkeyManagerTests: XCTestCase {
    @MainActor
    private func makeSUT() -> (sut: HotkeyManager, tapController: MockHotkeyEventTapController) {
        let tapController = MockHotkeyEventTapController()
        let sut = HotkeyManager(eventTapController: tapController)
        return (sut, tapController)
    }

    @MainActor
    func testStartWithoutPermissionsReportsMissingPermissions() {
        let context = makeSUT()
        context.sut.updatePermissionSnapshot(
            PermissionSnapshot(
                microphone: .authorized,
                accessibility: .denied,
                inputMonitoring: .denied
            )
        )

        context.sut.start()

        XCTAssertEqual(context.sut.monitoringStatus, .missingPermissions)
        XCTAssertEqual(context.tapController.installCount, 0)
    }

    @MainActor
    func testPermissionRecoveryInstallsTapAndBecomesReady() {
        let context = makeSUT()
        context.sut.updatePermissionSnapshot(
            PermissionSnapshot(
                microphone: .authorized,
                accessibility: .denied,
                inputMonitoring: .denied
            )
        )
        context.sut.start()

        context.sut.updatePermissionSnapshot(
            PermissionSnapshot(
                microphone: .authorized,
                accessibility: .authorized,
                inputMonitoring: .authorized
            )
        )

        XCTAssertEqual(context.sut.monitoringStatus, .ready)
        XCTAssertEqual(context.tapController.installCount, 1)
    }

    @MainActor
    func testTapDisabledEventReEnablesMonitoring() {
        let context = makeSUT()
        let recorder = StatusRecorder()
        context.sut.onStatusChanged = { status in
            recorder.record(status)
        }
        context.sut.updatePermissionSnapshot(
            PermissionSnapshot(
                microphone: .authorized,
                accessibility: .authorized,
                inputMonitoring: .authorized
            )
        )
        context.sut.start()

        let event = CGEvent(source: nil) ?? XCTFailAndReturnEvent()
        _ = context.sut.handleEvent(type: .tapDisabledByTimeout, event: event)

        XCTAssertTrue(recorder.statuses.contains(.temporarilyDisabled))
        XCTAssertEqual(context.sut.monitoringStatus, .ready)
        XCTAssertEqual(context.tapController.enabledValues.last, true)
    }

    @MainActor
    func testRepeatedStartStopDoesNotDuplicateTapInstallations() {
        let context = makeSUT()
        context.sut.updatePermissionSnapshot(
            PermissionSnapshot(
                microphone: .authorized,
                accessibility: .authorized,
                inputMonitoring: .authorized
            )
        )

        context.sut.start()
        context.sut.start()
        context.sut.stop()
        context.sut.stop()

        XCTAssertEqual(context.tapController.installCount, 1)
        XCTAssertEqual(context.tapController.uninstallCount, 1)
        XCTAssertEqual(context.sut.monitoringStatus, .stopped)
    }

    @MainActor
    func testFnFlagsChangedEmitsSingleTap() {
        let context = makeSUT()
        let expectation = expectation(description: "Single tap emitted")
        context.sut.onGesture = { gesture in
            if case .singleTap = gesture {
                expectation.fulfill()
            }
        }

        let keyDown = CGEvent(source: nil) ?? XCTFailAndReturnEvent()
        keyDown.type = .flagsChanged
        keyDown.flags = .maskSecondaryFn
        keyDown.setIntegerValueField(.keyboardEventKeycode, value: 63)

        let keyUp = CGEvent(source: nil) ?? XCTFailAndReturnEvent()
        keyUp.type = .flagsChanged
        keyUp.flags = []
        keyUp.setIntegerValueField(.keyboardEventKeycode, value: 63)

        _ = context.sut.handleEvent(type: .flagsChanged, event: keyDown)
        _ = context.sut.handleEvent(type: .flagsChanged, event: keyUp)

        waitForExpectations(timeout: 1.0)
    }
}

private final class StatusRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [HotkeyMonitoringStatus] = []

    func record(_ status: HotkeyMonitoringStatus) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(status)
    }

    var statuses: [HotkeyMonitoringStatus] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private func XCTFailAndReturnEvent(
    file: StaticString = #filePath,
    line: UInt = #line
) -> CGEvent {
    XCTFail("Unable to create CGEvent for test", file: file, line: line)
    return CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: .zero, mouseButton: .left)!
}
