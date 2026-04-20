import Foundation
@testable import Yapper

final class MockLLMProcessor: LLMProcessorProtocol, @unchecked Sendable {
    func process(text: String, option: SmartModeOption) async throws -> String {
        return "Processed " + text
    }

    func process(text: String, instruction: String) async throws -> String {
        return "Processed " + text + " with " + instruction
    }
}
