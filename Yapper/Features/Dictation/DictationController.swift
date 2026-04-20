import Foundation

final class DictationController: @unchecked Sendable {
    private var audioEngine: AudioEngineProtocol
    private var transcriber: TranscriberProtocol
    private var llmProcessor: LLMProcessorProtocol
    private var textInserter: TextInserterProtocol

    // Callbacks — set by AppDelegate before use
    var onPartialTranscript: (@Sendable (String) -> Void)?
    var onSessionFinished: (@Sendable (RecordingSessionResult) -> Void)?
    var onRecordingStopped: (@Sendable () -> Void)?
    var onError: (@Sendable (Error) -> Void)?
    var onAudioMeter: (@Sendable (AudioMeter) -> Void)?
    var onModelLoaded: (@Sendable () -> Void)?

    private(set) var isModelLoaded = false
    private var isRecording = false
    private var activeConfiguration: RecordingSessionConfiguration?
    private var activeSession: RecordingSession?
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
            guard let self, self.isRecording, self.activeConfiguration?.autoStopOnSilence == true else { return }
            self.stopRecording()
        }

        audioEngine.onMeter = { [weak self] meter in
            self?.activeSession?.meter = meter
            self?.onAudioMeter?(meter)
        }

        transcriber.onPartial = { [weak self] text in
            guard let self else { return }
            self.currentTranscript = text
            self.activeSession?.partialTranscript = text
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

    func startRecording(configuration: RecordingSessionConfiguration) {
        guard !isRecording else { return }
        isRecording = true
        activeConfiguration = configuration
        activeSession = RecordingSession(purpose: configuration.purpose)
        currentTranscript = ""

        let settings = SettingsManager.shared.settings
        audioEngine.silenceThreshold = settings.silenceThreshold
        audioEngine.silenceDetectionEnabled = configuration.autoStopOnSilence && settings.silenceDetectionEnabled
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
        if activeSession == nil, let purpose = activeConfiguration?.purpose {
            activeSession = RecordingSession(purpose: purpose)
        }
        activeSession?.partialTranscript = finalText

        onRecordingStopped?()

        if let activeConfiguration, activeConfiguration.shouldInsertText {
            let settings = SettingsManager.shared.settings
            let insertionOutcome = textInserter.insert(text: finalText, method: settings.insertionMethod)
            finishSession(transcript: finalText, insertionOutcome: insertionOutcome)
        } else if activeConfiguration?.purpose == .meeting {
            finishSession(transcript: finalText, insertionOutcome: nil)
        }
        // Smart mode waits for an explicit follow-up action.
    }

    // MARK: - Smart Mode

    func handleSmartModeSelection(_ option: SmartModeOption) {
        let text = currentTranscript

        if option == .cancel {
            let settings = SettingsManager.shared.settings
            let insertionOutcome = textInserter.insert(text: text, method: settings.insertionMethod)
            finishSession(transcript: text, insertionOutcome: insertionOutcome)
            return
        }

        Task { [weak self] in
            guard let self else { return }
            do {
                let processed = try await self.llmProcessor.process(text: text, option: option)
                let settings = SettingsManager.shared.settings
                let insertionOutcome = self.textInserter.insert(text: processed, method: settings.insertionMethod)
                self.finishSession(transcript: processed, insertionOutcome: insertionOutcome)
            } catch {
                print("[DictationController] LLM error: \(error) — falling back to raw text")
                let settings = SettingsManager.shared.settings
                let insertionOutcome = self.textInserter.insert(text: text, method: settings.insertionMethod)
                self.finishSession(transcript: text, insertionOutcome: insertionOutcome)
            }
        }
    }

    func discardRecording() {
        guard isRecording else { return }
        isRecording = false
        audioEngine.stop()
        _ = transcriber.stop()
        currentTranscript = ""
        activeConfiguration = nil
        activeSession = nil
    }

    private func finishSession(transcript: String, insertionOutcome: InsertionOutcome?) {
        guard let session = activeSession ?? activeConfiguration.map({ RecordingSession(purpose: $0.purpose) }) else {
            return
        }

        let result = RecordingSessionResult(
            session: session,
            transcript: transcript,
            insertionOutcome: insertionOutcome
        )
        activeConfiguration = nil
        activeSession = nil
        onSessionFinished?(result)
    }
}
