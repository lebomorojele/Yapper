import Foundation
import AVFoundation

@preconcurrency import AVFAudio

final class AudioEngine: @unchecked Sendable {
    var onAudio: (@Sendable ([Float]) -> Void)?
    var onSilence: (@Sendable () -> Void)?
    var onLevel: (@Sendable (Float) -> Void)?

    var silenceThreshold: TimeInterval = 1.5
    var silenceDetectionEnabled: Bool = true
    var inputGain: Float = 1.0

    private var engine: AVAudioEngine?
    private var isRunning = false
    private var silenceStart: Date?

    private let targetSampleRate: Double = 16000
    private let bufferSize: AVAudioFrameCount = 4096
    private let silenceLevelThreshold: Float = 0.05

    private var targetFormat: AVAudioFormat?

    init() {
        targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: targetSampleRate,
            channels: 1,
            interleaved: false
        )
    }

    func start() {
        guard !isRunning else { return }
        
        let settings = SettingsManager.shared.settings
        self.silenceThreshold = settings.silenceThreshold
        self.silenceDetectionEnabled = settings.silenceDetectionEnabled
        self.inputGain = settings.inputGain

        let eng = AVAudioEngine()
        engine = eng

        let input = eng.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        input.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            self?.processBuffer(buffer, inputFormat: inputFormat)
        }

        do {
            try eng.start()
            isRunning = true
            silenceStart = nil
            print("[AudioEngine] Started — input format: \(inputFormat)")
        } catch {
            print("[AudioEngine] Failed to start: \(error)")
        }
    }

    func stop() {
        guard isRunning else { return }
        engine?.stop()
        engine?.inputNode.removeTap(onBus: 0)
        engine = nil
        isRunning = false
        silenceStart = nil
    }

    // MARK: - Internal

    private func processBuffer(_ buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat) {
        guard let targetFormat else { return }

        // Calculate audio level from raw buffer
        let rms = calculateRMS(buffer)
        let db = 20 * log10(max(rms, 0.0001))
        let normalizedLevel = max(0, min(1, (db + 60) / 60))
        onLevel?(normalizedLevel)

        // Silence detection
        if silenceDetectionEnabled {
            if normalizedLevel < silenceLevelThreshold {
                if silenceStart == nil {
                    silenceStart = Date()
                } else if let start = silenceStart,
                          Date().timeIntervalSince(start) >= silenceThreshold {
                    onSilence?()
                    silenceStart = nil
                }
            } else {
                silenceStart = nil
            }
        }

        // Convert to 16 kHz mono Float32 for Parakeet
        let samples: [Float]

        if inputFormat.sampleRate == targetSampleRate && inputFormat.channelCount == 1 {
            // Already correct format
            guard let data = buffer.floatChannelData?[0] else { return }
            samples = Array(UnsafeBufferPointer(start: data, count: Int(buffer.frameLength)))
        } else {
            guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else { return }

            let ratio = targetSampleRate / inputFormat.sampleRate
            let frameCount = AVAudioFrameCount(Double(buffer.frameLength) * ratio)
            guard let converted = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else { return }

            var error: NSError?
            let inputBuffer = buffer  // let binding for Swift 6
            let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
                outStatus.pointee = .haveData
                return inputBuffer
            }

            converter.convert(to: converted, error: &error, withInputFrom: inputBlock)

            guard error == nil,
                  let data = converted.floatChannelData?[0] else { return }
            samples = Array(UnsafeBufferPointer(start: data, count: Int(converted.frameLength)))
        }

        guard !samples.isEmpty else { return }
        
        let processedSamples = inputGain > 1.0 ? samples.map { $0 * inputGain } : samples
        onAudio?(processedSamples)
    }

    private func calculateRMS(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<count {
            let s = data[i] * inputGain // Apply gain here
            sum += s * s
        }
        return sqrt(sum / Float(count))
    }
}
