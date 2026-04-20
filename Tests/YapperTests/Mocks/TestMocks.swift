import Foundation
import AVFoundation
@testable import Yapper

final class MockAudioEngine: AudioEngineProtocol {
    var onAudio: (@Sendable ([Float]) -> Void)?
    var onSilence: (@Sendable () -> Void)?
    var onLevel: (@Sendable (Float) -> Void)?
    
    var silenceThreshold: TimeInterval = 1.5
    var silenceDetectionEnabled: Bool = true
    var inputGain: Float = 1.0
    
    var isRunning = false
    
    func start() { isRunning = true }
    func stop() { isRunning = false }
    
    // Test helpers
    func simulateSilence() { onSilence?() }
    func simulateAudio(level: Float) { onLevel?(level) }
}

final class MockTranscriber: TranscriberProtocol {
    var onPartial: (@Sendable (String) -> Void)?
    var onFinal: (@Sendable (String) -> Void)?
    
    var shouldFail = false
    
    func loadModel() async throws { if shouldFail { throw NSError(domain: "test", code: 1) } }
    func start() {}
    func stop() -> String { return "Final transcript" }
    func process(samples: [Float]) {}
    
    // Test helpers
    func emitFinal(_ text: String) { onFinal?(text) }
}

final class MockTextInserter: TextInserterProtocol {
    var insertedText: String?
    var insertionOutcome: InsertionOutcome = .accessibility
    
    func insert(text: String, method: InsertionMethod) -> InsertionOutcome {
        insertedText = text
        return insertionOutcome
    }
    func checkAccessibilityPermission() -> Bool { return true }
    func requestAccessibilityPermission() {}
}
