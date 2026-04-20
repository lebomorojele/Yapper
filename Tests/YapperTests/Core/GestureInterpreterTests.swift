import XCTest
@testable import Yapper

@MainActor
final class GestureInterpreterTests: XCTestCase {
    var sut: GestureInterpreter!
    
    override func setUp() {
        super.setUp()
        sut = GestureInterpreter()
    }
    
    func testSingleTap() {
        let expectation = expectation(description: "Single tap detected")
        sut.onGesture = { gesture in
            if case .singleTap = gesture { expectation.fulfill() }
        }
        
        sut.keyDown()
        sut.keyUp()
        
        waitForExpectations(timeout: 1.0)
    }
    
    func testDoubleTap() {
        let expectation = expectation(description: "Double tap detected")
        sut.onGesture = { gesture in
            if case .doubleTap = gesture { expectation.fulfill() }
        }
        
        // First tap
        sut.keyDown()
        sut.keyUp()
        
        // Second tap
        sut.keyDown()
        sut.keyUp()
        
        waitForExpectations(timeout: 1.0)
    }
}
