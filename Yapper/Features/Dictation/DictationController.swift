import Foundation

final class DictationController: @unchecked Sendable {
    private var audioEngine: AudioEngineProtocol
    private var transcriber: TranscriberProtocol
    private var llmProcessor: LLMProcessorProtocol
    private var textInserter: TextInserterProtocol

    // Callbacks — set by AppDelegate before use
    var onPartialTranscript: (@Sendable (String) -> Void)?
    var onFinalTranscript: (@Sendable (String, InsertionOutcome) -> Void)?
    var onRecordingStopped: (@Sendable () -> Void)?
    var onError: (@Sendable (Error) -> Void)?
    var onAudioLevel: (@Sendable (Float) -> Void)?
    var onModelLoaded: (@Sendable () -> Void)?

    private(set) var isModelLoaded = false
    private var isRecording = false
    private var isSmartMode = false
    private var currentTranscript = ""

    init(
        audioEngine: AudioEngineProtocol,
        transcriber: TranscriberProtocol,
        llmProcessor: LLMProcessorProtocol,
        textInserter: TextInserterProtocol
    ) {
        self.audioEngine = audioEngine
        self.transcriber = transcriber
        self.llmProcessor = llmProcessor
        self.textInserter = textInserter
        wireCallbacks()
    }

    // MARK: - Setup

    private func wireCallbacks() {
        audioEngine.onAudio = { [weak self] samples in
            self?.transcriber.process(samples: samples)
        }

        audioEngine.onSilence = { [weak self] in
            guard let self, self.isRecording else { return }
            self.stopRecording()
        }

        audioEngine.onLevel = { [weak self] level in
            self?.onAudioLevel?(level)
        }

        transcriber.onPartial = { [weak self] text in
            guard let self else { return }
            self.currentTranscript = text
            self.onPartialTranscript?(text)
        }

        transcriber.onFinal = { [weak self] text in
            guard let self else { return }
            self.currentTranscript = text
        }
    }

    // MARK: - Model

    func loadModel() async {
        do {
            try await transcriber.loadModel()
            isModelLoaded = true
            print("[DictationController] Model ready")
            onModelLoaded?()
        } catch {
            print("[DictationController] Model load failed: \(error)")
            onError?(error)
        }
    }

    // MARK: - Recording

    func startRecording(smartMode: Bool = false) {
        guard !isRecording else { return }
        isRecording = true
        isSmartMode = smartMode
        currentTranscript = ""

        let settings = SettingsManager.shared.settings
        audioEngine.silenceThreshold = settings.silenceThreshold
        audioEngine.silenceDetectionEnabled = settings.silenceDetectionEnabled
        audioEngine.inputGain = settings.inputGain

        transcriber.start()
        audioEngine.start()
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false

        audioEngine.stop()
        let finalText = transcriber.stop()
        currentTranscript = finalText

        onRecordingStopped?()

        if !isSmartMode {
            // Quick dictation — insert text immediately
            let settings = SettingsManager.shared.settings
            let insertionOutcome = textInserter.insert(text: finalText, method: settings.insertionMethod)
            onFinalTranscript?(finalText, insertionOutcome)
        }
        // In smart mode, wait for handleSmartModeSelection
    }

    // MARK: - Smart Mode

    func handleSmartModeSelection(_ option: SmartModeOption) {
        let text = currentTranscript

        if option == .cancel {
            let settings = SettingsManager.shared.settings
            let insertionOutcome = textInserter.insert(text: text, method: settings.insertionMethod)
            onFinalTranscript?(text, insertionOutcome)
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let processed = try await self.llmProcessor.process(text: text, option: option)
                let settings = SettingsManager.shared.settings
                let insertionOutcome = self.textInserter.insert(text: processed, method: settings.insertionMethod)
                self.onFinalTranscript?(processed, insertionOutcome)
            } catch {
                print("[DictationController] LLM error: \(error) — falling back to raw text")
                let settings = SettingsManager.shared.settings
                let insertionOutcome = self.textInserter.insert(text: text, method: settings.insertionMethod)
                self.onFinalTranscript?(text, insertionOutcome)
            }
        }
    }
}
