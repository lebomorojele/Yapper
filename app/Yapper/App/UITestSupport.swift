import Foundation
import AppKit
import AVFoundation

enum UITestLaunchOption {
    static let enabled = "YAPPER_UI_TEST_MODE"
    static let openWelcome = "YAPPER_OPEN_WELCOME_ON_LAUNCH"
    static let openSettings = "YAPPER_OPEN_SETTINGS_ON_LAUNCH"
}

enum UITestSupport {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment[UITestLaunchOption.enabled] == "1"
    }

    static func configureIfNeeded() {
        guard isEnabled else { return }
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
    }

    static func shouldOpenWelcomeOnLaunch() -> Bool {
        isEnabled && ProcessInfo.processInfo.environment[UITestLaunchOption.openWelcome] == "1"
    }

    static func shouldOpenSettingsOnLaunch() -> Bool {
        ProcessInfo.processInfo.environment[UITestLaunchOption.openSettings] == "1"
    }
    @MainActor
    static func runBundledSpeechCheckIfRequested() -> Bool {
        guard isEnabled, let path = ProcessInfo.processInfo.environment["YAPPER_VERIFY_AUDIO_PATH"] else { return false }
        Task {
            do {
                let file = try AVAudioFile(forReading: URL(fileURLWithPath: path))
                guard file.processingFormat.sampleRate == 16_000, file.processingFormat.channelCount == 1,
                      let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
                    throw NSError(domain: "Yapper.BundleCheck", code: 1)
                }
                try file.read(into: buffer)
                guard let data = buffer.floatChannelData?[0] else { throw NSError(domain: "Yapper.BundleCheck", code: 2) }
                let samples = Array(UnsafeBufferPointer(start: data, count: Int(buffer.frameLength)))
                let transcriber = ParakeetTranscriber()
                try await transcriber.loadModel()
                try transcriber.start()
                for repetition in 0..<2 {
                    if repetition > 0 { transcriber.process(samples: [Float](repeating: 0, count: 64_000)) }
                    for offset in stride(from: 0, to: samples.count, by: 5120) {
                        transcriber.process(samples: Array(samples[offset..<min(offset + 5120, samples.count)]))
                    }
                }
                let text = transcriber.stop().lowercased()
                guard text.contains("guarantee"), text.components(separatedBy: "shipped tomorrow").count - 1 == 2 else {
                    throw NSError(domain: "Yapper.BundleCheck", code: 3, userInfo: [NSLocalizedDescriptionKey: "Recorded speech did not match the expected phrases."])
                }
                FileHandle.standardOutput.write(Data("[Bundled speech] passed\n".utf8))
            } catch {
                print("[Bundled speech] failed: \(error.localizedDescription)")
            }
            NSApp.terminate(nil)
        }
        return true
    }

}
