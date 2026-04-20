import XCTest
@testable import Yapper

final class PermissionManagerTests: XCTestCase {
    func testPermissionStates() {
        let manager = PermissionManager.shared
        // These will return current system states (usually true/false)
        XCTAssertNotNil(manager.isMicrophoneAuthorized)
        XCTAssertNotNil(manager.isAccessibilityAuthorized)
    }
}
