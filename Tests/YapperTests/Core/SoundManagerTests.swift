import XCTest
@testable import Yapper

final class SoundManagerTests: XCTestCase {
    func testPlaySound() {
        // Just ensuring it doesn't crash on execution.
        SoundManager.shared.play(.recordingStart)
        SoundManager.shared.play(.recordingStop)
        SoundManager.shared.play(.meetingStart)
        SoundManager.shared.play(.meetingStop)
        SoundManager.shared.play(.processingComplete)
        SoundManager.shared.play(.smartMenuOpen)
        XCTAssertTrue(true)
    }
}
