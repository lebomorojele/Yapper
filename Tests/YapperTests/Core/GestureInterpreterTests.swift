import XCTest
@testable import Yapper

@MainActor
final class GestureInterpreterTests: XCTestCase {
    var sut: GestureInterpreter!

    override func setUp() async throws {
        try await super.setUp()
        sut = GestureInterpreter()
    }

    func testSingleTap() {
        let expectation = expectation(description: "Single tap detected")
        sut.onGesture = { gesture in
            if case .singleTap = gesture {
                expectation.fulfill()
            }
        }

        sut.keyDown()
        sut.keyUp()

        waitForExpectations(timeout: 1.0)
    }

    func testRepeatedKeyDownOnlyEmitsOneTapAfterRelease() {
        let expectation = expectation(description: "Single tap detected once")
        expectation.expectedFulfillmentCount = 1
        sut.onGesture = { _ in expectation.fulfill() }

        sut.keyDown()
        sut.keyDown()
        sut.keyUp()

        waitForExpectations(timeout: 1.0)
    }
}
