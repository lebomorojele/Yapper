import XCTest
@testable import Yapper

@MainActor
final class SettingsTests: XCTestCase {
    func testSettingsManagerDefaults() {
        let settings = SettingsManager.shared.settings
        XCTAssertEqual(settings.insertionMethod, .axuiElement)
        XCTAssertTrue(settings.cleanupEnabled)
        XCTAssertEqual(settings.modelCleanupWordThreshold, 10)
    }
    
    func testUpdateSettings() {
        let originalSettings = SettingsManager.shared.settings
        defer { SettingsManager.shared.settings = originalSettings }

        SettingsManager.shared.update {
            $0.cleanupEnabled = false
            $0.modelCleanupWordThreshold = 16
        }
        XCTAssertFalse(SettingsManager.shared.settings.cleanupEnabled)
        XCTAssertEqual(SettingsManager.shared.settings.modelCleanupWordThreshold, 16)
    }
}
