import Foundation
import ParakeetStreamingASR

final class ParakeetTranscriber: TranscriberProtocol, @unchecked Sendable {
    var onPartial: (@Sendable (String) -> Void)?
    var onFinal: (@Sendable (String) -> Void)?

    private var model: ParakeetStreamingASRModel?
    private var session: StreamingSession?
    private var isRunning = false
    private var accumulatedText = ""

    private let queue = DispatchQueue(label: "com.yapper.transcriber")

    // MARK: - Model Loading

    func loadModel() async throws {
        let m = try await ParakeetStreamingASRModel.fromPretrained(
            modelId: ParakeetStreamingASRModel.defaultModelId
        ) { progress, status in
            print("[Parakeet] \(status) (\(Int(progress * 100))%)")
        }
        try m.warmUp()
        model = m
        print("[Parakeet] Model loaded and warmed up")
    }

    // MARK: - Session Lifecycle

    func start() {
        queue.sync {
            guard !isRunning else { return }
            isRunning = true
            accumulatedText = ""

            guard let model else {
                print("[Parakeet] Model not loaded — cannot start session")
                return
            }

            do {
                session = try model.createSession()
            } catch {
                print("[Parakeet] Failed to create session: \(error)")
            }
        }
    }

    /// Stops transcription, finalizes the session, and returns the result.
    @discardableResult
    func stop() -> String {
        var result = ""
        queue.sync {
            guard isRunning else {
                result = accumulatedText
                return
            }
            isRunning = false

            if let session {
                do {
                    let finals = try session.finalize()
                    for partial in finals where !partial.text.isEmpty {
                        accumulatedText = partial.text
                    }
                } catch {
                    print("[Parakeet] Finalize error: \(error)")
                }
            }
            session = nil
            result = accumulatedText
        }
        onFinal?(result)
        return result
    }

    // MARK: - Audio Processing

    /// Push audio samples (16 kHz mono Float32) into the streaming session.
    func process(samples: [Float]) {
        queue.async { [weak self] in
            guard let self, self.isRunning, let session = self.session else { return }

            do {
                let partials = try session.pushAudio(samples)
                for partial in partials {
                    if partial.isFinal {
                        self.accumulatedText = partial.text
                        self.onFinal?(partial.text)
                    } else if !partial.text.isEmpty {
                        self.accumulatedText = partial.text
                        self.onPartial?(partial.text)
                    }
                }
            } catch {
                print("[Parakeet] pushAudio error: \(error)")
            }
        }
    }
}
