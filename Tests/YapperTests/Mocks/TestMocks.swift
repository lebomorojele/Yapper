import Foundation
import AVFoundation
@testable import Yapper

final class MockAudioEngine: AudioEngineProtocol {
    var onAudio: (@Sendable ([Float]) -> Void)?
    var onSilence: (@Sendable () -> Void)?
    var onMeter: (@Sendable (AudioMeter) -> Void)?

    var silenceThreshold: TimeInterval = 1.5
    var silenceDetectionEnabled: Bool = true
    var inputGain: Float = 1.0

    var isRunning = false

    func start() { isRunning = true }
    func stop() { isRunning = false }

    func simulateSilence() { onSilence?() }
    func simulateAudio(level: Float) {
        onMeter?(AudioMeter(level: level, peak: level, bars: Array(repeating: level, count: 6)))
    }
}

final class MockTranscriber: TranscriberProtocol {
    var onPartial: (@Sendable (String) -> Void)?
    var onFinal: (@Sendable (String) -> Void)?

    var shouldFail = false
    var finalText = "Final transcript"

    func loadModel() async throws {
        if shouldFail {
            throw NSError(domain: "test", code: 1)
        }
    }

    func start() {}
    func stop() -> String { finalText }
    func process(samples: [Float]) {}

    func emitFinal(_ text: String) { onFinal?(text) }
}

final class MockTextCleanupProcessor: TextCleanupProcessing, @unchecked Sendable {
    var output: String?
    var error: Error?
    private(set) var inputs: [String] = []

    func clean(text: String) async throws -> String {
        inputs.append(text)
        if let error {
            throw error
        }
        return output ?? text
    }
}

final class MockTextInserter: TextInserterProtocol {
    var insertedText: String?
    var insertionOutcome: InsertionOutcome = .accessibility

    func insert(text: String, method: InsertionMethod) -> InsertionOutcome {
        insertedText = text
        return insertionOutcome
    }

    func checkAccessibilityPermission() -> Bool { true }
    func requestAccessibilityPermission() {}
}

final class MockPermissionManager: PermissionManaging, @unchecked Sendable {
    var currentSnapshot = PermissionSnapshot(
        microphone: .authorized,
        accessibility: .authorized,
        inputMonitoring: .authorized
    )
    private(set) var requestedMicrophone = false
    private(set) var requestedAccessibility = false
    private(set) var requestedInputMonitoring = false

    func snapshot() -> PermissionSnapshot {
        currentSnapshot
    }

    func requestMicrophonePermission() async -> PermissionAuthorizationStatus {
        requestedMicrophone = true
        return currentSnapshot.microphone
    }

    func requestAccessibilityPermission() {
        requestedAccessibility = true
    }

    func requestInputMonitoringPermission() {
        requestedInputMonitoring = true
    }
}

final class MockHotkeyManager: HotkeyManaging, @unchecked Sendable {
    var onGesture: (@Sendable (InputGesture) -> Void)?
    var onStatusChanged: (@Sendable (HotkeyMonitoringStatus) -> Void)?

    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var refreshCallCount = 0
    private(set) var permissionSnapshots: [PermissionSnapshot] = []

    func start() {
        startCallCount += 1
    }

    func stop() {
        stopCallCount += 1
    }

    func refreshMonitoringState() {
        refreshCallCount += 1
    }

    func updatePermissionSnapshot(_ snapshot: PermissionSnapshot) {
        permissionSnapshots.append(snapshot)
    }
}

final class MockDictationController: DictationControlling, @unchecked Sendable {
    var onPartialTranscript: (@Sendable (String) -> Void)?
    var onSessionFinished: (@Sendable (RecordingSessionResult) -> Void)?
    var onRecordingStopped: (@Sendable () -> Void)?
    var onError: (@Sendable (Error) -> Void)?
    var onAudioMeter: (@Sendable (AudioMeter) -> Void)?
    var onModelLoaded: (@Sendable () -> Void)?

    private(set) var startConfigurations: [RecordingSessionConfiguration] = []
    private(set) var stopCallCount = 0
    private(set) var discardCallCount = 0

    func loadModel() async {
        onModelLoaded?()
    }

    func startRecording(configuration: RecordingSessionConfiguration) {
        startConfigurations.append(configuration)
    }

    func stopRecording() {
        stopCallCount += 1
    }

    func discardRecording() {
        discardCallCount += 1
    }
}
