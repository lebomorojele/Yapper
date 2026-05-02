import XCTest
@testable import Yapper

final class PillContentViewTests: XCTestCase {
    @MainActor
    func testPreferredWidthForShortTranscriptIsContentDriven() {
        let width = PillContentView.preferredWidth(for: .listening, partialTranscript: "hello there")

        XCTAssertGreaterThan(width, 72)
        XCTAssertLessThan(width, 320)
    }

    @MainActor
    func testPreferredWidthForLongTranscriptCapsAtMaximum() {
        let width = PillContentView.preferredWidth(
            for: .listening,
            partialTranscript: "extraordinary hypercommunication counterintuitive mischaracterization overrepresentation intercontinentalism disproportionateness uncharacteristically"
        )

        XCTAssertEqual(width, 320)
    }

    @MainActor
    func testResolvedWidthDoesNotShrinkDuringActiveTranscript() {
        let initialWidth = PillContentView.preferredWidth(
            for: .listening,
            partialTranscript: "you but it's looking kind of crazy"
        )

        let resolvedWidth = PillContentView.resolvedWidth(
            currentWidth: initialWidth,
            state: .listening,
            partialTranscript: "kind of"
        )

        XCTAssertEqual(resolvedWidth, initialWidth)
    }

    @MainActor
    func testResolvedWidthShrinksForCompletionState() {
        let activeWidth = PillContentView.preferredWidth(
            for: .listening,
            partialTranscript: "you but it's looking kind of crazy"
        )

        let completionWidth = PillContentView.resolvedWidth(
            currentWidth: activeWidth,
            state: .inserted,
            partialTranscript: ""
        )

        XCTAssertLessThan(completionWidth, activeWidth)
    }
}
