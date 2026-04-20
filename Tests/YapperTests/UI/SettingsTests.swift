import XCTest
@testable import Yapper

@MainActor
final class SettingsTests: XCTestCase {
    func testSettingsManagerDefaults() {
        // Reset to default for testing
        SettingsManager.shared.update { $0.aiProvider = "OpenAI" }
        let settings = SettingsManager.shared.settings
        XCTAssertEqual(settings.aiProvider, "OpenAI")
        XCTAssertTrue(settings.saveTranscripts)
    }
    
    func testUpdateSettings() {
        SettingsManager.shared.update { $0.aiProvider = "Anthropic" }
        XCTAssertEqual(SettingsManager.shared.settings.aiProvider, "Anthropic")
    }
}
