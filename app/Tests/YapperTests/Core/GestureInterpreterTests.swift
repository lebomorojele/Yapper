import XCTest
@testable import Yapper

@MainActor
final class GestureInterpreterTests: XCTestCase {
    func testSingleTap() {
        let sut = GestureInterpreter()
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
        let sut = GestureInterpreter()
        let expectation = expectation(description: "Single tap detected once")
        expectation.expectedFulfillmentCount = 1
        sut.onGesture = { _ in expectation.fulfill() }

        sut.keyDown()
        sut.keyDown()
        sut.keyUp()

        waitForExpectations(timeout: 1.0)
    }
}
