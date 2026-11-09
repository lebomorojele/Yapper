import Foundation

@MainActor
final class DictationController {
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
    var onModelProgress: (@Sendable (Double) -> Void)?
    var onModelLoaded: (@Sendable () -> Void)?

    private(set) var isModelLoaded = false
    private var isRecording = false
    private var activeConfiguration: RecordingSessionConfiguration?
    private var activeSession: RecordingSession?

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
        transcriber.onLoadProgress = { [weak self] progress in
            Task { @MainActor in self?.onModelProgress?(progress) }
        }
        let transcriber = self.transcriber
        audioEngine.onAudio = { samples in transcriber.process(samples: samples) }
    }

    private func wireSessionCallbacks(sessionID: UUID) {
        audioEngine.onSilence = { [weak self] in
            Task { @MainActor in
                guard let self, self.activeSession?.id == sessionID,
                      self.isRecording, self.activeConfiguration?.autoStopOnSilence == true else { return }
                self.stopRecording()
            }
        }
        audioEngine.onMeter = { [weak self] meter in
            Task { @MainActor in
                guard let self, self.activeSession?.id == sessionID, self.isRecording else { return }
                self.activeSession?.meter = meter
                self.onAudioMeter?(meter)
            }
        }
        transcriber.onPartial = { [weak self] text in
            Task { @MainActor in
                guard let self, self.activeSession?.id == sessionID, self.isRecording else { return }
                self.activeSession?.partialTranscript = text
                self.onPartialTranscript?(text)
            }
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
        guard !isRecording, activeSession == nil else { return }
        isRecording = true
        activeConfiguration = configuration
        let session = RecordingSession()
        activeSession = session
        wireSessionCallbacks(sessionID: session.id)

        let settings = SettingsManager.shared.settings
        audioEngine.silenceThreshold = settings.silenceThreshold
        audioEngine.silenceDetectionEnabled = configuration.autoStopOnSilence && settings.silenceDetectionEnabled
        audioEngine.inputGain = settings.inputGain

        do {
            try transcriber.start()
            try audioEngine.start()
        } catch {
            discardRecording()
            onError?(error)
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        isRecording = false

        audioEngine.stop()
        let finalText = transcriber.stop()

        if activeSession == nil {
            activeSession = RecordingSession()
        }
        activeSession?.partialTranscript = finalText

        onRecordingStopped?()

        guard activeConfiguration?.shouldInsertText == true else {
            finishSession(transcript: finalText, insertionOutcome: nil)
            return
        }

        let sessionID = activeSession?.id
        Task { @MainActor [weak self] in
            await self?.finishInsertedSession(rawTranscript: finalText, sessionID: sessionID)
        }
    }

    func discardRecording() {
        guard isRecording else {
            activeConfiguration = nil
            activeSession = nil
            return
        }

        isRecording = false
        audioEngine.stop()
        _ = transcriber.stop()
        activeConfiguration = nil
        activeSession = nil
    }

    private func finishInsertedSession(rawTranscript: String, sessionID: UUID?) async {
        guard activeSession?.id == sessionID else { return }
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
                guard activeSession?.id == sessionID else { return }
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

        guard activeSession?.id == sessionID else { return }
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
