import AVFoundation
import XCTest
@testable import Yapper

final class RealTranscriptionTests: XCTestCase {
    func testRecordedSpeechSurvivesTheStreamingPipeline() async throws {
        guard ProcessInfo.processInfo.environment["YAPPER_RUN_STT_INTEGRATION"] == "1" else {
            throw XCTSkip("Set YAPPER_RUN_STT_INTEGRATION=1 to download the speech model and run real recognition.")
        }
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: Self.self)
        #endif
        let url = try XCTUnwrap(bundle.url(forResource: "speech", withExtension: "wav", subdirectory: "Fixtures"))
        let file = try AVAudioFile(forReading: url)
        XCTAssertEqual(file.processingFormat.sampleRate, 16_000)
        XCTAssertEqual(file.processingFormat.channelCount, 1)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        let channel = try XCTUnwrap(buffer.floatChannelData?[0])
        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        let transcriber = ParakeetTranscriber()
        try await transcriber.loadModel()
        try transcriber.start()
        for offset in stride(from: 0, to: samples.count, by: 5120) {
            transcriber.process(samples: Array(samples[offset..<min(offset + 5120, samples.count)]))
        }
        let text = transcriber.stop().lowercased()
        XCTAssertTrue(text.contains("guarantee"), "Expected the recorded speech, got: \(text)")
        XCTAssertTrue(text.contains("shipped tomorrow"), "Expected the end of the recording, got: \(text)")
    }
}
