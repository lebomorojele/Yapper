import Foundation

final class DictationController: @unchecked Sendable {
    private var audioEngine: AudioEngineProtocol
    private var transcriber: TranscriberProtocol
    private var textCleanupProcessor: TextCleanupProcessing
    private var textInserter: TextInserterProtocol
    private let heuristicTextCleanupProcessor: TextCleanupProcessing

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
        textCleanupProcessor: TextCleanupProcessing,
        textInserter: TextInserterProtocol,
        heuristicTextCleanupProcessor: TextCleanupProcessing = HeuristicTextCleanupProcessor()
    ) {
        self.audioEngine = audioEngine
        self.transcriber = transcriber
        self.textCleanupProcessor = textCleanupProcessor
        self.textInserter = textInserter
        self.heuristicTextCleanupProcessor = heuristicTextCleanupProcessor
        wireCallbacks()
    }

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
            self?.currentTranscript = text
        }
    }

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

    func startRecording(configuration: RecordingSessionConfiguration) {
        guard !isRecording else { return }
        isRecording = true
        activeConfiguration = configuration
        activeSession = RecordingSession()
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

        if activeSession == nil {
            activeSession = RecordingSession()
        }
        activeSession?.partialTranscript = finalText

        onRecordingStopped?()

        guard activeConfiguration?.shouldInsertText == true else {
            finishSession(transcript: finalText, insertionOutcome: nil)
            return
        }

        Task { [weak self] in
            await self?.finishInsertedSession(rawTranscript: finalText)
        }
    }

    func discardRecording() {
        guard isRecording else {
            activeConfiguration = nil
            activeSession = nil
            currentTranscript = ""
            return
        }

        isRecording = false
        audioEngine.stop()
        _ = transcriber.stop()
        currentTranscript = ""
        activeConfiguration = nil
        activeSession = nil
    }

    private func finishInsertedSession(rawTranscript: String) async {
        let trimmed = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            finishSession(transcript: trimmed, insertionOutcome: nil)
            return
        }

        let settings = SettingsManager.shared.settings
        var outputText: String
        if settings.cleanupEnabled {
            let fastOutput = await cleanedTextUsingHeuristic(from: trimmed)
            guard shouldUseModelCleanup(for: trimmed, settings: settings) else {
                let insertionOutcome = textInserter.insert(text: fastOutput, method: settings.insertionMethod)
                finishSession(transcript: fastOutput, insertionOutcome: insertionOutcome)
                return
            }

            do {
                let cleaned = try await textCleanupProcessor.clean(text: fastOutput)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                outputText = cleaned.isEmpty ? fastOutput : cleaned
            } catch {
                print("[DictationController] Cleanup failed: \(error) — inserting fast-path transcript")
                outputText = fastOutput
            }
        } else {
            outputText = trimmed
        }

        let insertionOutcome = textInserter.insert(text: outputText, method: settings.insertionMethod)
        finishSession(transcript: outputText, insertionOutcome: insertionOutcome)
    }

    private func cleanedTextUsingHeuristic(from text: String) async -> String {
        do {
            let cleaned = try await heuristicTextCleanupProcessor.clean(text: text)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return cleaned.isEmpty ? text : cleaned
        } catch {
            return text
        }
    }

    private func shouldUseModelCleanup(for text: String, settings: Settings) -> Bool {
        let threshold = settings.modelCleanupWordThreshold
        if threshold <= 0 {
            return true
        }

        let wordCount = text
            .split(whereSeparator: \.isWhitespace)
            .count
        return wordCount >= threshold
    }

    private func finishSession(transcript: String, insertionOutcome: InsertionOutcome?) {
        guard let session = activeSession else { return }

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
