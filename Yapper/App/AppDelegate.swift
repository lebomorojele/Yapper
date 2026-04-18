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
            button.image = NSImage(
                systemSymbolName: "waveform",
                accessibilityDescription: "Yapper"
            )
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

    // MARK: - Gesture Handling

    private func handleGesture(_ gesture: InputGesture) {
        switch gesture {
        case .singleTap:
            if case .recording = recordingState {
                stopRecording()
            } else if recordingState == .idle {
                startRecording(smartMode: false)
            }

        case .doubleTap:
            if case .recording = recordingState {
                stopRecording()
            }
            startRecording(smartMode: true)

        case .holdStart:
            if recordingState == .idle {
                startRecording(smartMode: false)
            }

        case .holdEnd:
            // Spec: hold starts, release continues, tap to stop
            // holdEnd intentionally does nothing
            break
        }
    }

    // MARK: - Recording Control

    private func startRecording(smartMode: Bool) {
        guard modelReady else {
            print("[Yapper] Model not ready — ignoring start request")
            return
        }
        recordingState = .recording(isSmartMode: smartMode)
        isSmartMode = smartMode
        currentTranscript = ""
        currentAudioLevel = 0

        dictationController.startRecording(smartMode: smartMode)
        floatingPanel?.showAtTopCenter()
        updateUI()
    }

    private func stopRecording() {
        dictationController.stopRecording()
        // Remaining state updates happen in onRecordingStopped callback
    }

    // MARK: - Smart Mode

    private func showSmartModeOptions() {
        floatingPanel?.updateContent(
            state: .idle,
            partialTranscript: currentTranscript,
            showOptions: true,
            audioLevel: 0,
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
            onOptionSelected: { _ in }
        )

        dictationController.handleSmartModeSelection(option)
        // onFinalTranscript callback will hide the panel
    }

    // MARK: - UI Updates

    private func updateUI() {
        guard case .recording = recordingState else { return }

        floatingPanel?.updateContent(
            state: recordingState,
            partialTranscript: currentTranscript,
            showOptions: false,
            audioLevel: currentAudioLevel,
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
        } else {
            startRecording(smartMode: false)
        }
    }

    @objc private func openPreferences() {
        // Preferences window — v0.2
    }

    @objc private func quitApp() {
        hotkeyManager.stop()
        NSApp.terminate(nil)
    }
}
