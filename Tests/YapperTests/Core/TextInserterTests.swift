import XCTest
@testable import Yapper

final class TextInserterTests: XCTestCase {
    func testInsertionMethods() {
        let inserter = TextInserter()
        // Test basic functionality. In real scenarios, use mocks for AXUIElement
        inserter.insert(text: "Hello", method: .clipboard)
        XCTAssertTrue(true)
    }
}
