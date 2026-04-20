import Foundation
@testable import Yapper

final class MockLLMProcessor: LLMProcessorProtocol {
    func process(text: String, option: SmartModeOption) async throws -> String {
        return "Processed " + text
    }
}
