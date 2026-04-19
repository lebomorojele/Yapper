import Foundation

protocol AudioEngineProtocol {
    var onAudio: (@Sendable ([Float]) -> Void)? { get set }
    var onSilence: (@Sendable () -> Void)? { get set }
    var onLevel: (@Sendable (Float) -> Void)? { get set }
    
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

protocol LLMProcessorProtocol {
    func process(text: String, option: SmartModeOption) async throws -> String
}

protocol TextInserterProtocol {
    func insert(text: String, method: InsertionMethod) -> InsertionOutcome
    func checkAccessibilityPermission() -> Bool
    func requestAccessibilityPermission()
}

// Concrete conformances for App usage
extension LLMProcessor: LLMProcessorProtocol {}
extension TextInserter: TextInserterProtocol {}
