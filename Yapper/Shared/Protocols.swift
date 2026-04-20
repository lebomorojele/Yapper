import Foundation

protocol DictationControlling: AnyObject, Sendable {
    var onPartialTranscript: (@Sendable (String) -> Void)? { get set }
    var onSessionFinished: (@Sendable (RecordingSessionResult) -> Void)? { get set }
    var onRecordingStopped: (@Sendable () -> Void)? { get set }
    var onError: (@Sendable (Error) -> Void)? { get set }
    var onAudioMeter: (@Sendable (AudioMeter) -> Void)? { get set }
    var onModelLoaded: (@Sendable () -> Void)? { get set }

    func loadModel() async
    func startRecording(configuration: RecordingSessionConfiguration)
    func stopRecording()
    func handleSmartModeSelection(_ option: SmartModeOption)
    func discardRecording()
}

protocol HotkeyManaging: AnyObject, Sendable {
    var onGesture: (@Sendable (InputGesture) -> Void)? { get set }
    var onStatusChanged: (@Sendable (HotkeyMonitoringStatus) -> Void)? { get set }

    func start()
    func stop()
    func refreshMonitoringState()
    func updatePermissionSnapshot(_ snapshot: PermissionSnapshot)
}

protocol PermissionManaging: AnyObject, Sendable {
    func snapshot() -> PermissionSnapshot
    func requestMicrophonePermission() async -> PermissionAuthorizationStatus
    func requestAccessibilityPermission()
    func requestInputMonitoringPermission()
}

protocol AudioEngineProtocol {
    var onAudio: (@Sendable ([Float]) -> Void)? { get set }
    var onSilence: (@Sendable () -> Void)? { get set }
    var onMeter: (@Sendable (AudioMeter) -> Void)? { get set }
    
    func start()
    func stop()
    var silenceThreshold: TimeInterval { get set }
    var silenceDetectionEnabled: Bool { get set }
    var inputGain: Float { get set }
}

protocol TranscriberProtocol {
    var onPartial: (@Sendable (String) -> Void)? { get set }
    var onFinal: (@Sendable (String) -> Void)? { get set }
    
    func loadModel() async throws
    func start()
    func stop() -> String
    func process(samples: [Float])
}

protocol LLMProcessorProtocol: Sendable {
    func process(text: String, option: SmartModeOption) async throws -> String
    func process(text: String, instruction: String) async throws -> String
}

protocol TextInserterProtocol {
    func insert(text: String, method: InsertionMethod) -> InsertionOutcome
    func checkAccessibilityPermission() -> Bool
    func requestAccessibilityPermission()
}

protocol HistoryStoreProtocol: Sendable {
    func loadEntries() throws -> [HistoryEntry]
    func save(entry: HistoryEntry) throws
    func update(entry: HistoryEntry) throws
}

// Concrete conformances for App usage
extension DictationController: DictationControlling {}
extension HotkeyManager: HotkeyManaging {}
extension PermissionManager: PermissionManaging {}
extension LLMProcessor: LLMProcessorProtocol {}
extension TextInserter: TextInserterProtocol {}
