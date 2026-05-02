import XCTest
import AppKit
@testable import Yapper

final class TextInserterTests: XCTestCase {
    func testClipboardInsertionLeavesTextOnPasteboard() {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("com.yapper.tests.\(UUID().uuidString)"))
        pasteboard.clearContents()
        pasteboard.setString("Previous", forType: .string)

        let inserter = TextInserter(pasteboard: pasteboard, pasteHandler: {})

        let outcome = inserter.insert(text: "Hello", method: .clipboard)

        XCTAssertEqual(outcome, .clipboard)
        XCTAssertEqual(pasteboard.string(forType: .string), "Hello")
    }
}
