import Foundation
import ParakeetStreamingASR

final class ParakeetTranscriber: TranscriberProtocol, @unchecked Sendable {
    var onLoadProgress: (@Sendable (Double) -> Void)?
    var onPartial: (@Sendable (String) -> Void)?
    var onFinal: (@Sendable (String) -> Void)?

    private var model: ParakeetStreamingASRModel?
    private var session: StreamingSession?
    private var isRunning = false
    private var transcript = StreamingTranscript()

    private let queue = DispatchQueue(label: "com.yapper.transcriber")

    // MARK: - Model Loading

    func loadModel() async throws {
        let m = try await ParakeetStreamingASRModel.fromPretrained(
            modelId: ParakeetStreamingASRModel.defaultModelId
        ) { [weak self] progress, status in
            self?.onLoadProgress?(progress)
            print("[Parakeet] \(status) (\(Int(progress * 100))%)")
        }
        try m.warmUp()
        model = m
        print("[Parakeet] Model loaded and warmed up")
    }

    // MARK: - Session Lifecycle

    func start() throws {
        try queue.sync {
            guard !isRunning else { return }
            transcript = StreamingTranscript()

            guard let model else {
                throw NSError(domain: "Yapper.Transcription", code: 1, userInfo: [NSLocalizedDescriptionKey: "The speech model is not ready. Try loading it again from the Yapper menu."])
            }

            session = try model.createSession()
            isRunning = true
        }
    }

    /// Stops transcription, finalizes the session, and returns the result.
    @discardableResult
    func stop() -> String {
        var result = ""
        queue.sync {
            guard isRunning else {
                result = transcript.text
                return
            }
            isRunning = false

            if let session {
                do {
                    // Keep finals emitted while draining the trailing audio, before finalize advances its EOU offset.
                    if let model {
                        let chunkSize = model.config.streaming.melFrames * model.config.hopLength
                        consume(try session.pushAudio([Float](repeating: 0, count: chunkSize)))
                    }
                    consume(try session.finalize())
                } catch {
                    print("[Parakeet] Finalize error: \(error)")
                }
            }
            session = nil
            result = transcript.text
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
                self.consume(try session.pushAudio(samples))
            } catch {
                print("[Parakeet] pushAudio error: \(error)")
            }
        }
    }
    private func consume(_ partials: [ParakeetStreamingASRModel.PartialTranscript]) {
        for partial in partials where !partial.text.isEmpty {
            transcript.update(segment: partial.segmentIndex, text: partial.text)
            let completeText = transcript.text
            onPartial?(completeText)
            if partial.isFinal { onFinal?(completeText) }
        }
    }

}
