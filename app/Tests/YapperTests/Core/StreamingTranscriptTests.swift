import XCTest
@testable import Yapper

final class StreamingTranscriptTests: XCTestCase {
    func testPartialRevisionsReplaceOnlyTheirOwnSegment() {
        var transcript = StreamingTranscript()
        transcript.update(segment: 0, text: "hello")
        transcript.update(segment: 0, text: "hello world")
        XCTAssertEqual(transcript.text, "hello world")
    }

    func testPausesDoNotDiscardEarlierUtterances() {
        var transcript = StreamingTranscript()
        transcript.update(segment: 0, text: "First thought.")
        transcript.update(segment: 1, text: "Second")
        transcript.update(segment: 1, text: "Second thought.")
        transcript.update(segment: 2, text: "Third thought.")
        XCTAssertEqual(transcript.text, "First thought. Second thought. Third thought.")
    }

    func testRepeatedWordsAcrossUtterancesArePreserved() {
        var transcript = StreamingTranscript()
        transcript.update(segment: 0, text: "Thank you.")
        transcript.update(segment: 3, text: "Thank you.")
        XCTAssertEqual(transcript.text, "Thank you. Thank you.")
    }

    func testFinalRevisionKeepsLaterSegmentsInOrder() {
        var transcript = StreamingTranscript()
        transcript.update(segment: 0, text: "first")
        transcript.update(segment: 2, text: "Second thought.")
        transcript.update(segment: 0, text: "First thought.")
        XCTAssertEqual(transcript.text, "First thought. Second thought.")
    }

    func testEmptyFinalDoesNotEraseRecognizedSpeech() {
        var transcript = StreamingTranscript()
        transcript.update(segment: 0, text: "A complete thought.")
        transcript.update(segment: 0, text: "  ")
        XCTAssertEqual(transcript.text, "A complete thought.")
    }
}
