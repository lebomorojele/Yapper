import AppKit
import AVFoundation

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var floatingPanel: FloatingPanel?
    private let dictationController = DictationController()
    private let hotkeyManager = HotkeyManager()

    private var recordingState: RecordingState = .idle
    private var currentTranscript = ""
    private var isSmartMode = false
    private var currentAudioLevel: Float = 0
    private var recordingStartTime: Date? = nil
    private var modelReady = false

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
            } else if recordingState == .idle {
                startRecording(smartMode: false)
            }

        case .doubleTap:
            if case .recording = recordingState {
                stopRecording()
            } else if recordingState == .recordingMeeting {
                stopMeetingRecording()
            }
            startRecording(smartMode: true)

        case .holdStart:
            if recordingState == .idle {
                startMeetingRecording()
            } else if recordingState == .recordingMeeting {
                stopMeetingRecording()
            } else if case .recording = recordingState {
                stopRecording()
            }

        case .holdEnd:
            // Release after hold means we stay in the meeting recording until tapped again
            break
        }
    }

    private func setupDictation() {
        dictationController.onPartialTranscript = { [weak self] text in
            Task { @MainActor in
                self?.currentTranscript = text
                self?.updateUI()
            }
        }

        dictationController.onFinalTranscript = { [weak self] _ in
            Task { @MainActor in
                self?.recordingState = .idle
                self?.floatingPanel?.hidePanel()
            }
        }

        dictationController.onRecordingStopped = { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                if self.isSmartMode {
                    self.showSmartModeOptions()
                } else {
                    self.recordingState = .idle
                    // Panel will be hidden by onFinalTranscript
                }
            }
        }

        dictationController.onAudioLevel = { [weak self] level in
            Task { @MainActor in
                self?.currentAudioLevel = level
                if case .recording = self?.recordingState {
                    self?.updateUI()
                }
            }
        }

        dictationController.onModelLoaded = { [weak self] in
            Task { @MainActor in
                self?.modelReady = true
                print("[Yapper] Model ready — fn key active")
            }
        }

        dictationController.onError = { error in
            print("[Yapper] Error: \(error)")
        }

        // Load the Parakeet model in background
        print("[Yapper] Loading Parakeet model...")
        Task {
            await dictationController.loadModel()
        }
    }

    // MARK: - Meeting Mode (Stub)

    private func startMeetingRecording() {
        guard modelReady else { return }
        recordingState = .recordingMeeting
        SoundManager.shared.play(.meetingStart)
        currentTranscript = ""
        currentAudioLevel = 0
        recordingStartTime = Date()

        // In a real implementation, this would likely bypass `dictationController` and write directly to an audio file
        // or a chunked transcription pipeline optimized for 1+ hour meetings.
        print("[Yapper] 🎙️ Started Meeting Recording")
        
        floatingPanel?.showAtTopCenter()
        updateUI()
    }

    private func stopMeetingRecording() {
        guard recordingState == .recordingMeeting else { return }
        recordingState = .processing
        
        print("[Yapper] 🛑 Stopped Meeting Recording")
        SoundManager.shared.play(.meetingStop)
        
        floatingPanel?.updateContent(
            state: .processing,
            partialTranscript: "",
            showOptions: false,
            recordingStartTime: nil,
            onOptionSelected: { _ in }
        )
        
        // Processing -> Complete -> Idle
        Task {
            // Process for 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            await MainActor.run {
                self.recordingState = .complete
            SoundManager.shared.play(.processingComplete)
            }
            
            // Show complete state for 1.5 seconds
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            
            await MainActor.run {
                print("[Yapper] 📝 Meeting Summary Generated")
                self.recordingState = .idle
                self.floatingPanel?.hidePanel()
            }
        }
    }

    // MARK: - Recording Control

    private func startRecording(smartMode: Bool) {
        guard modelReady else {
            print("[Yapper] Model not ready — ignoring start request")
            return
        }
        recordingState = .recording(isSmartMode: smartMode)
        SoundManager.shared.play(smartMode ? .smartMenuOpen : .recordingStart)
        isSmartMode = smartMode
        currentTranscript = ""
        currentAudioLevel = 0
        recordingStartTime = Date()

        dictationController.startRecording(smartMode: smartMode)
        floatingPanel?.showAtTopCenter()
        updateUI()
    }

    private func stopRecording() {
        SoundManager.shared.play(.recordingStop)
        dictationController.stopRecording()
        // Remaining state updates happen in onRecordingStopped callback
    }

    // MARK: - Smart Mode

    private func showSmartModeOptions() {
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
        if option == .cancel {
            recordingState = .idle
            floatingPanel?.hidePanel()
            return
        }

        recordingState = .processing
        floatingPanel?.updateContent(
            state: .processing,
            partialTranscript: "",
            showOptions: false,
            recordingStartTime: nil,
            onOptionSelected: { _ in }
        )

        dictationController.handleSmartModeSelection(option)
        // onFinalTranscript callback will hide the panel
    }

    // MARK: - UI Updates

    private func updateUI() {
        if recordingState == .idle || recordingState == .processing { return }

        floatingPanel?.updateContent(
            state: recordingState,
            partialTranscript: currentTranscript,
            showOptions: false,
            audioLevel: currentAudioLevel,
            recordingStartTime: recordingStartTime,
            onOptionSelected: { _ in }
        )
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
