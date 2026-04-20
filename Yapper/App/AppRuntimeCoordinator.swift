import Foundation

@MainActor
final class AppRuntimeCoordinator {
    var onStateChange: ((AppRuntimeState) -> Void)?

    private let dictationController: DictationControlling
    private let hotkeyManager: HotkeyManaging
    private let permissionManager: PermissionManaging
    private let historyStore: HistoryStoreProtocol

    private(set) var state = AppRuntimeState() {
        didSet {
            onStateChange?(state)
        }
    }

    private var completionDismissTask: Task<Void, Never>?

    init(
        dictationController: DictationControlling,
        hotkeyManager: HotkeyManaging,
        permissionManager: PermissionManaging = PermissionManager.shared,
        historyStore: HistoryStoreProtocol = HistoryStore.shared
    ) {
        self.dictationController = dictationController
        self.hotkeyManager = hotkeyManager
        self.permissionManager = permissionManager
        self.historyStore = historyStore
        bindCallbacks()
    }

    func start() {
        refreshPermissions()
        requestInitialPermissionsIfNeeded()
        hotkeyManager.start()
        loadModel()
    }

    func stop() {
        cleanupForDisposition(.cancel)
        hotkeyManager.stop()
        resetToIdle()
    }

    func appDidBecomeActive() {
        refreshPermissions()
        hotkeyManager.refreshMonitoringState()
    }

    func handleMenuToggleRecording() {
        switch state.recordingPhase {
        case .recording, .recordingSmart:
            stopActiveRecording()
        case .recordingMeeting:
            stopMeetingRecording()
        default:
            startRecording(purpose: .dictation)
        }
    }

    func handleGesture(_ gesture: InputGesture) {
        switch gesture {
        case .singleTap:
            switch state.recordingPhase {
            case .recording, .recordingSmart:
                stopActiveRecording()
            case .recordingMeeting:
                stopMeetingRecording()
            case .idle, .completed, .cancelled, .failed, .processing, .selectingSmartMode, .preparing:
                startRecording(purpose: .dictation)
            }

        case .doubleTap:
            switch state.recordingPhase {
            case .recording, .recordingSmart:
                cleanupForDisposition(.discard)
                resetToIdle()
            case .recordingMeeting:
                stopMeetingRecording()
            default:
                startRecording(purpose: .smart)
            }

        case .holdStart:
            switch state.recordingPhase {
            case .idle, .completed, .cancelled, .failed, .processing, .selectingSmartMode, .preparing:
                startRecording(purpose: .meeting)
            case .recordingMeeting:
                stopMeetingRecording()
            case .recording, .recordingSmart:
                cleanupForDisposition(.cancel)
                resetToIdle()
            }

        case .holdEnd:
            break
        }
    }

    func selectSmartMode(_ option: SmartModeOption) {
        guard state.recordingPhase == .selectingSmartMode else { return }
        state.recordingPhase = .processing
        dictationController.handleSmartModeSelection(option)
    }

    private func bindCallbacks() {
        hotkeyManager.onGesture = { [weak self] gesture in
            Task { @MainActor in
                self?.handleGesture(gesture)
            }
        }

        hotkeyManager.onStatusChanged = { [weak self] status in
            Task { @MainActor in
                self?.state.hotkeyMonitoringStatus = status
            }
        }

        dictationController.onPartialTranscript = { [weak self] text in
            Task { @MainActor in
                guard let self else { return }
                self.state.session?.partialTranscript = text
                switch self.state.recordingPhase {
                case .preparing:
                    self.state.recordingPhase = self.state.session?.purpose == .smart ? .recordingSmart : .recording
                default:
                    break
                }
            }
        }

        dictationController.onSessionFinished = { [weak self] result in
            Task { @MainActor in
                self?.handleFinishedSession(result)
            }
        }

        dictationController.onRecordingStopped = { [weak self] in
            Task { @MainActor in
                self?.handleRecordingStopped()
            }
        }

        dictationController.onAudioMeter = { [weak self] meter in
            Task { @MainActor in
                self?.state.session?.meter = meter
            }
        }

        dictationController.onError = { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                self.cleanupForDisposition(.failure(error.localizedDescription))
                self.state.recordingPhase = .failed(error.localizedDescription)
                self.scheduleCompletionDismiss()
            }
        }

        dictationController.onModelLoaded = { [weak self] in
            Task { @MainActor in
                self?.state.modelReady = true
            }
        }
    }

    private func refreshPermissions() {
        state.permissions = permissionManager.snapshot()
        hotkeyManager.updatePermissionSnapshot(state.permissions)
    }

    private func requestInitialPermissionsIfNeeded() {
        if state.permissions.microphone == .notDetermined {
            Task { [weak self] in
                guard let self else { return }
                _ = await self.permissionManager.requestMicrophonePermission()
                await MainActor.run {
                    self.refreshPermissions()
                }
            }
        }

        if state.permissions.accessibility != .authorized {
            permissionManager.requestAccessibilityPermission()
        }

        if state.permissions.inputMonitoring != .authorized {
            permissionManager.requestInputMonitoringPermission()
        }
    }

    private func loadModel() {
        Task { [weak self] in
            guard let self else { return }
            await self.dictationController.loadModel()
        }
    }

    private func startRecording(purpose: RecordingPurpose) {
        guard state.modelReady else {
            state.recordingPhase = .failed("Model not ready")
            scheduleCompletionDismiss()
            return
        }

        completionDismissTask?.cancel()
        completionDismissTask = nil

        let session = RecordingSession(purpose: purpose)
        state.session = session
        state.recordingStartTime = session.startedAt
        state.recordingPhase = purpose == .meeting ? .recordingMeeting : .preparing

        dictationController.startRecording(
            configuration: RecordingSessionConfiguration(
                purpose: purpose,
                autoStopOnSilence: purpose != .meeting,
                shouldInsertText: purpose != .meeting && purpose != .smart
            )
        )

        if purpose == .dictation {
            state.recordingPhase = .recording
        } else if purpose == .smart {
            state.recordingPhase = .recordingSmart
        }
    }

    private func stopActiveRecording() {
        switch state.recordingPhase {
        case .recording:
            state.recordingPhase = .processing
            dictationController.stopRecording()
        case .recordingSmart:
            dictationController.stopRecording()
        default:
            break
        }
    }

    private func stopMeetingRecording() {
        guard state.recordingPhase == .recordingMeeting else { return }
        state.recordingPhase = .processing
        dictationController.stopRecording()
    }

    private func handleRecordingStopped() {
        switch state.recordingPhase {
        case .recordingSmart:
            state.recordingPhase = .selectingSmartMode
        case .recording, .recordingMeeting:
            state.recordingPhase = .processing
        default:
            break
        }
    }

    private func handleFinishedSession(_ result: RecordingSessionResult) {
        let duration = max(0, Date().timeIntervalSince(result.session.startedAt))
        var entry = HistoryEntry(
            kind: result.session.purpose == .meeting ? .meeting : .dictation,
            transcript: result.transcript,
            createdAt: result.session.startedAt,
            duration: duration,
            insertionOutcome: result.insertionOutcome
        )

        if result.session.purpose == .meeting {
            do {
                entry.exportedFilePath = try TranscriptExporter.exportTranscript(entry, settings: SettingsManager.shared.settings)
            } catch {
                entry.enrichment.lastError = "Could not export transcript: \(error.localizedDescription)"
            }
        }

        try? historyStore.save(entry: entry)

        state.session = nil
        state.recordingStartTime = nil
        state.recordingPhase = .completed(result.insertionOutcome)
        scheduleCompletionDismiss()
    }

    private func cleanupForDisposition(_ disposition: RecordingDisposition) {
        completionDismissTask?.cancel()
        completionDismissTask = nil

        switch disposition {
        case .stop:
            dictationController.stopRecording()
        case .cancel, .discard, .failure:
            dictationController.discardRecording()
        case .completion:
            break
        }

        switch disposition {
        case .cancel, .discard:
            state.recordingPhase = .cancelled
            scheduleCompletionDismiss()
        case .failure(let error):
            state.recordingPhase = .failed(error)
            scheduleCompletionDismiss()
        case .stop, .completion:
            break
        }

        state.session = nil
        state.recordingStartTime = nil
    }

    private func scheduleCompletionDismiss() {
        completionDismissTask?.cancel()
        completionDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            await MainActor.run {
                self?.resetToIdle()
            }
        }
    }

    private func resetToIdle() {
        completionDismissTask?.cancel()
        completionDismissTask = nil
        state.recordingPhase = .idle
        state.session = nil
        state.recordingStartTime = nil
    }
}
