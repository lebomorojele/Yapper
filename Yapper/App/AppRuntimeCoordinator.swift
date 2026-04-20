import Foundation

@MainActor
final class AppRuntimeCoordinator {
    var onStateChange: ((AppRuntimeState) -> Void)?

    private let dictationController: DictationController
    private let hotkeyManager: HotkeyManager
    private let permissionManager: PermissionManager

    private(set) var state = AppRuntimeState() {
        didSet {
            onStateChange?(state)
        }
    }

    private var completionDismissTask: Task<Void, Never>?

    init(
        dictationController: DictationController,
        hotkeyManager: HotkeyManager,
        permissionManager: PermissionManager = .shared
    ) {
        self.dictationController = dictationController
        self.hotkeyManager = hotkeyManager
        self.permissionManager = permissionManager
        bindCallbacks()
    }

    func start() {
        refreshPermissions()
        requestInitialPermissionsIfNeeded()
        hotkeyManager.start()
        loadModel()
    }

    func stop() {
        completionDismissTask?.cancel()
        completionDismissTask = nil
        hotkeyManager.stop()
        if isActiveRecordingPhase(state.recordingPhase) {
            dictationController.stopRecording()
        }
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
            startRecording(smartMode: false)
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
            case .idle, .completed, .failed, .processing, .selectingSmartMode, .preparing:
                startRecording(smartMode: false)
            }

        case .doubleTap:
            switch state.recordingPhase {
            case .recording, .recordingSmart:
                stopActiveRecording()
                resetToIdle()
            case .recordingMeeting:
                stopMeetingRecording()
            default:
                startRecording(smartMode: true)
            }

        case .holdStart:
            switch state.recordingPhase {
            case .idle, .completed, .failed, .processing, .selectingSmartMode, .preparing:
                startMeetingRecording()
            case .recordingMeeting:
                stopMeetingRecording()
            case .recording, .recordingSmart:
                stopActiveRecording()
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
                self.state.partialTranscript = text
                switch self.state.recordingPhase {
                case .preparing:
                    self.state.recordingPhase = .recording
                default:
                    break
                }
            }
        }

        dictationController.onFinalTranscript = { [weak self] text, insertionOutcome in
            Task { @MainActor in
                guard let self else { return }
                self.state.partialTranscript = text
                self.state.audioLevel = 0
                self.state.recordingPhase = .completed(insertionOutcome)
                self.scheduleCompletionDismiss()
            }
        }

        dictationController.onRecordingStopped = { [weak self] in
            Task { @MainActor in
                self?.handleRecordingStopped()
            }
        }

        dictationController.onAudioLevel = { [weak self] level in
            Task { @MainActor in
                guard let self else { return }
                self.state.audioLevel = level
            }
        }

        dictationController.onError = { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
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

    private func startRecording(smartMode: Bool) {
        guard state.modelReady else {
            state.recordingPhase = .failed("Model not ready")
            scheduleCompletionDismiss()
            return
        }

        completionDismissTask?.cancel()
        completionDismissTask = nil
        state.partialTranscript = ""
        state.audioLevel = 0
        state.recordingStartTime = Date()
        state.recordingPhase = .preparing

        dictationController.startRecording(smartMode: smartMode, autoStopOnSilence: true)
        state.recordingPhase = smartMode ? .recordingSmart : .recording
    }

    private func startMeetingRecording() {
        guard state.modelReady else {
            state.recordingPhase = .failed("Model not ready")
            scheduleCompletionDismiss()
            return
        }

        completionDismissTask?.cancel()
        completionDismissTask = nil
        state.partialTranscript = ""
        state.audioLevel = 0
        state.recordingStartTime = Date()
        state.recordingPhase = .recordingMeeting
        dictationController.startRecording(smartMode: false, autoStopOnSilence: false)
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
        state.partialTranscript = ""
        state.audioLevel = 0
        state.recordingStartTime = nil
    }

    private func isActiveRecordingPhase(_ phase: RuntimeRecordingPhase) -> Bool {
        switch phase {
        case .preparing, .recording, .recordingSmart, .recordingMeeting:
            return true
        default:
            return false
        }
    }
}
