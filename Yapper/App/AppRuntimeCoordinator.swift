import Foundation

@MainActor
final class AppRuntimeCoordinator {
    var onStateChange: ((AppRuntimeState) -> Void)?

    private let dictationController: DictationControlling
    private let hotkeyManager: HotkeyManaging
    private let permissionManager: PermissionManaging

    private(set) var state = AppRuntimeState() {
        didSet {
            onStateChange?(state)
        }
    }

    private var completionDismissTask: Task<Void, Never>?
    private var restartAfterProcessing = false

    init(
        dictationController: DictationControlling,
        hotkeyManager: HotkeyManaging,
        permissionManager: PermissionManaging = PermissionManager.shared
    ) {
        self.dictationController = dictationController
        self.hotkeyManager = hotkeyManager
        self.permissionManager = permissionManager
        bindCallbacks()
    }

    func start() {
        state.recordingPhase = .loading
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
        toggleRecording()
    }

    func handleGesture(_ gesture: InputGesture) {
        switch gesture {
        case .singleTap:
            toggleRecording()
        }
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
                self?.state.session?.partialTranscript = text
            }
        }

        dictationController.onSessionFinished = { [weak self] result in
            Task { @MainActor in
                self?.handleFinishedSession(result)
            }
        }

        dictationController.onRecordingStopped = { [weak self] in
            Task { @MainActor in
                guard let self, self.state.recordingPhase == .recording else { return }
                self.state.recordingPhase = .processing
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
            }
        }

        dictationController.onModelLoaded = { [weak self] in
            Task { @MainActor in
                self?.state.modelReady = true
                if self?.state.recordingPhase == .loading {
                    self?.state.recordingPhase = .idle
                }
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

    private func toggleRecording() {
        switch state.recordingPhase {
        case .recording:
            restartAfterProcessing = false
            state.recordingPhase = .processing
            Task { @MainActor [weak self] in
                self?.dictationController.stopRecording()
            }
        case .idle, .completed, .cancelled, .failed:
            startRecording()
        case .processing:
            restartAfterProcessing = true
        case .loading:
            break
        }
    }

    private func startRecording() {
        guard state.modelReady else {
            state.recordingPhase = .failed("Model not ready")
            scheduleCompletionDismiss()
            return
        }

        completionDismissTask?.cancel()
        completionDismissTask = nil

        let session = RecordingSession()
        state.session = session
        state.recordingStartTime = session.startedAt
        state.recordingPhase = .recording

        dictationController.startRecording(
            configuration: RecordingSessionConfiguration(
                autoStopOnSilence: true,
                shouldInsertText: true
            )
        )
    }

    private func handleFinishedSession(_ result: RecordingSessionResult) {
        state.session = nil
        state.recordingStartTime = nil

        if restartAfterProcessing {
            restartAfterProcessing = false
            startRecording()
            return
        }

        state.recordingPhase = .completed(result.insertionOutcome)
        scheduleCompletionDismiss()
    }

    private func cleanupForDisposition(_ disposition: RecordingDisposition) {
        completionDismissTask?.cancel()
        completionDismissTask = nil

        switch disposition {
        case .stop:
            dictationController.stopRecording()
        case .cancel, .failure:
            restartAfterProcessing = false
            dictationController.discardRecording()
        case .completion:
            break
        }

        switch disposition {
        case .cancel:
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
        restartAfterProcessing = false
        state.recordingPhase = state.modelReady ? .idle : .loading
        state.session = nil
        state.recordingStartTime = nil
    }
}
