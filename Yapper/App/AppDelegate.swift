import AppKit
import AVFoundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var floatingPanel: FloatingPanel?
    private let dictationController = DictationController(
        audioEngine: AudioEngine(),
        transcriber: ParakeetTranscriber(),
        llmProcessor: LLMProcessor(),
        textInserter: TextInserter()
    )
    private let hotkeyManager = HotkeyManager()

    private var recordingState: RecordingState = .idle
    private var isPendingSmartMode = false
    private var currentTranscript = ""
    private var isSmartMode = false
    private var currentAudioLevel: Float = 0
    private var recordingStartTime: Date? = nil
    private var modelReady = false
    private var isMeetingMode = false
    private var smartSelectionKeyMonitor: Any?

    // MARK: - App Lifecycle

    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            self.setupMenuBar()
            self.setupFloatingPanel()
            self.setupHotkey()
            self.setupDictation()
            self.requestPermissions()
            NSApp.setActivationPolicy(.accessory)
        }
    }

    // MARK: - Setup

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            // Use icon1.png for menu bar
            let iconPath = Bundle.main.path(forResource: "icon1", ofType: "png") 
                ?? NSHomeDirectory() + "/Documents/projects/Yapper/icon1.png"
            button.image = NSImage(contentsOfFile: iconPath)
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
        }

        let menu = NSMenu()

        let recordItem = NSMenuItem(
            title: "Start Recording",
            action: #selector(toggleRecording),
            keyEquivalent: "r"
        )
        recordItem.keyEquivalentModifierMask = .command
        menu.addItem(recordItem)

        menu.addItem(.separator())

        let prefsItem = NSMenuItem(
            title: "Preferences...",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        prefsItem.keyEquivalentModifierMask = .command
        menu.addItem(prefsItem)

        #if DEBUG
        let catalogItem = NSMenuItem(
            title: "UI Design Catalog...",
            action: #selector(openDesignCatalog),
            keyEquivalent: "d"
        )
        catalogItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(catalogItem)
        #endif

        menu.addItem(.separator())

        let quitItem = NSMenuItem(
            title: "Quit Yapper",
            action: #selector(quitApp),
            keyEquivalent: "q"
        )
        quitItem.keyEquivalentModifierMask = .command
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    private func setupFloatingPanel() {
        floatingPanel = FloatingPanel()
    }

    private func setupHotkey() {
        hotkeyManager.onGesture = { [weak self] gesture in
            Task { @MainActor in
                self?.handleGesture(gesture)
            }
        }
        hotkeyManager.start()
    }

    // MARK: - Gesture Handling

    private func handleGesture(_ gesture: InputGesture) {
        switch gesture {
        case .singleTap:
            if case .recording = recordingState {
                stopRecording()
            } else if recordingState == .recordingMeeting {
                stopMeetingRecording()
            } else if recordingState == .idle || recordingState == .ready {
                // UI updates FIRST for instant responsiveness
                self.isPendingSmartMode = false
                self.isSmartMode = false
                self.isMeetingMode = false
                self.currentTranscript = ""
                self.currentAudioLevel = 0
                self.recordingStartTime = Date()
                
                // Show UI immediately - then start audio
                self.recordingState = .recording(isSmartMode: false)
                self.floatingPanel?.showAtTopCenter()
                self.updateUI()
                
                // Play sound IMMEDIATELY
                SoundManager.shared.play(.recordingStart)
                
                // Start audio capture
                self.dictationController.startRecording(smartMode: false)
            }

        case .doubleTap:
            if case .recording = recordingState {
                stopRecording()
                self.recordingState = .idle
                self.floatingPanel?.hidePanel()
            } else if recordingState == .recordingMeeting {
                stopMeetingRecording()
            } else {
                // UI updates FIRST for instant responsiveness
                self.isPendingSmartMode = true
                self.isSmartMode = true
                self.isMeetingMode = false
                self.currentTranscript = ""
                self.currentAudioLevel = 0
                self.recordingStartTime = Date()
                
                // Show UI immediately - then start audio
                self.recordingState = .recording(isSmartMode: true)
                self.floatingPanel?.showAtTopCenter()
                self.updateUI()
                
                // Play sound IMMEDIATELY
                SoundManager.shared.play(.smartMenuOpen)
                
                // Start audio capture
                self.dictationController.startRecording(smartMode: true)
            }

        case .holdStart:
            if recordingState == .idle || recordingState == .ready {
                startMeetingRecording()
            } else if recordingState == .recordingMeeting {
                stopMeetingRecording()
            } else if case .recording = recordingState {
                stopRecording()
            }

        case .holdEnd:
            break
        }
    }

    private func setupDictation() {
        dictationController.onPartialTranscript = { [weak self] (text: String) in
            Task { @MainActor in
                guard let self else { return }
                // Transition from ready to recording (actively recording) on first partial text
                if self.recordingState == .ready {
                    self.recordingState = .recording(isSmartMode: self.isSmartMode)
                }
                self.currentTranscript = text
                self.updateUI()
            }
        }

        dictationController.onFinalTranscript = { [weak self] (text: String, insertionOutcome: InsertionOutcome) in
            Task { @MainActor in
                guard let self else { return }
                
                // Play success sound at the END of the user journey - when text is ready
                SoundManager.shared.play(.processingComplete)
                
                self.currentTranscript = text
                self.recordingState = insertionOutcome == .clipboard ? .completeClipboard : .complete
                self.updateUI()
                
                Task {
                    try? await Task.sleep(nanoseconds: 1_200_000_000)
                    await MainActor.run {
                        self.recordingState = .idle
                        self.floatingPanel?.hidePanel()
                    }
                }
            }
        }


        dictationController.onRecordingStopped = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.isSmartMode {
                    self.showSmartModeOptions()
                } else {
                    self.recordingState = .processing
                    self.updateUI()
                }
            }
        }

        dictationController.onAudioLevel = { [weak self] (level: Float) in
            Task { @MainActor in
                self?.currentAudioLevel = level
                if case .recording = self?.recordingState {
                    self?.updateUI()
                } else if self?.recordingState == .recordingMeeting {
                    self?.updateUI()
                }
            }
        }

        dictationController.onError = { (error: Error) in
            print("[Yapper] Error: \(error)")
        }

        dictationController.onModelLoaded = { [weak self] in
            Task { @MainActor in
                self?.modelReady = true
                print("[Yapper] Model ready, recording enabled")
            }
        }

        // Load the Parakeet model in background
        print("[Yapper] Loading Parakeet model...")
        Task {
            await dictationController.loadModel()
        }
    }

    // MARK: - Meeting Mode

    private func startMeetingRecording() {
        guard modelReady else { return }
        isMeetingMode = true
        isSmartMode = false
        recordingState = .recordingMeeting
        currentTranscript = ""
        currentAudioLevel = 0
        recordingStartTime = Date()
        SoundManager.shared.play(.meetingStart)
        print("[Yapper] 🎙️ Started Meeting Recording")

        floatingPanel?.showAtTopCenter()
        updateUI()
        dictationController.startRecording(smartMode: false, autoStopOnSilence: false)
    }

    private func stopMeetingRecording() {
        guard recordingState == .recordingMeeting else { return }
        recordingState = .processing
        updateUI()
        print("[Yapper] 🛑 Stopped Meeting Recording")
        dictationController.stopRecording()
    }

    // MARK: - Recording Control

    private func startRecording(smartMode: Bool) {
        guard modelReady else {
            print("[Yapper] Model not ready — ignoring start request")
            return
        }
        isMeetingMode = false
        recordingState = .recording(isSmartMode: smartMode)
        SoundManager.shared.play(smartMode ? .smartMenuOpen : .recordingStart)
        isSmartMode = smartMode
        currentTranscript = ""
        currentAudioLevel = 0
        recordingStartTime = Date()

        dictationController.startRecording(smartMode: smartMode, autoStopOnSilence: true)
        floatingPanel?.showAtTopCenter()
        updateUI()
    }

    private func stopRecording() {
        // Don't play stop sound here - we play success at the END when text is ready
        dictationController.stopRecording()
    }

    // MARK: - Smart Mode

    private func showSmartModeOptions() {
        installSmartSelectionKeyMonitor()
        SoundManager.shared.play(.smartMenuOpen)
        floatingPanel?.updateContent(
            state: .idle,
            partialTranscript: currentTranscript,
            showOptions: true,
            audioLevel: 0,
            recordingStartTime: recordingStartTime,
            onOptionSelected: { [weak self] option in
                self?.handleSmartModeSelection(option)
            }
        )
    }

    private func handleSmartModeSelection(_ option: SmartModeOption) {
        removeSmartSelectionKeyMonitor()
        recordingState = .processing
        floatingPanel?.updateContent(
            state: .processing,
            partialTranscript: "",
            showOptions: false,
            recordingStartTime: nil,
            onOptionSelected: { _ in }
        )

        dictationController.handleSmartModeSelection(option)
        // onFinalTranscript callback will show completion and then hide the panel
    }

    // MARK: - UI Updates

    private func updateUI() {
        if recordingState == .idle {
            removeSmartSelectionKeyMonitor()
            floatingPanel?.hidePanel()
            return
        }

        floatingPanel?.updateContent(
            state: recordingState,
            partialTranscript: currentTranscript,
            showOptions: false,
            audioLevel: currentAudioLevel,
            recordingStartTime: recordingStartTime,
            onOptionSelected: { _ in }
        )
    }

    private func installSmartSelectionKeyMonitor() {
        removeSmartSelectionKeyMonitor()

        smartSelectionKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            Task { @MainActor in
                self?.handleSmartSelectionKeyEvent(event)
            }
        }
    }

    private func removeSmartSelectionKeyMonitor() {
        if let smartSelectionKeyMonitor {
            NSEvent.removeMonitor(smartSelectionKeyMonitor)
            self.smartSelectionKeyMonitor = nil
        }
    }

    private func handleSmartSelectionKeyEvent(_ event: NSEvent) {
        guard isSmartMode else { return }

        switch event.charactersIgnoringModifiers {
        case "1":
            handleSmartModeSelection(.slack)
        case "2":
            handleSmartModeSelection(.chat)
        case "3":
            handleSmartModeSelection(.email)
        case "4":
            handleSmartModeSelection(.prompt)
        default:
            break
        }
    }

    // MARK: - Permissions

    private func requestPermissions() {
        AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
            if !granted {
                Task { @MainActor in
                    self?.showPermissionAlert("Microphone")
                }
            }
        }

        let inserter = TextInserter()
        if !inserter.checkAccessibilityPermission() {
            inserter.requestAccessibilityPermission()
        }
    }

    private func showPermissionAlert(_ permission: String) {
        let alert = NSAlert()
        alert.messageText = "\(permission) Permission Required"
        alert.informativeText = "Yapper needs \(permission) access to function properly. Please enable it in System Settings."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            let urlString: String
            switch permission {
            case "Microphone":
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
            default:
                urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
            }
            if let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Menu Actions

    @objc private func toggleRecording() {
        if case .recording = recordingState {
            stopRecording()
        } else if recordingState == .recordingMeeting {
            stopMeetingRecording()
        } else {
            startRecording(smartMode: false)
        }
    }

    @objc private func openPreferences() {
        SettingsWindowController.shared.show()
    }

    #if DEBUG
    @objc private func openDesignCatalog() {
        DesignCatalogWindowController.shared.show()
    }
    #endif

    @objc private func quitApp() {
        hotkeyManager.stop()
        NSApp.terminate(nil)
    }
}
