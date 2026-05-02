import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let processingIndicatorDelay: Duration = .milliseconds(180)

    private var statusItem: NSStatusItem?
    private var runtimeStatusItem: NSMenuItem?
    private var floatingPanel: FloatingPanel?
    private var processingIndicatorTask: Task<Void, Never>?
    private var previousSoundState: RecordingState?
    private var modelStatusCancellable: AnyCancellable?

    private let runtime = AppRuntimeCoordinator(
        dictationController: DictationController(
            audioEngine: AudioEngine(),
            transcriber: ParakeetTranscriber(),
            textCleanupProcessor: LlamaCppTextCleanupProcessor(),
            textInserter: TextInserter()
        ),
        hotkeyManager: HotkeyManager()
    )

    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            UITestSupport.configureIfNeeded()
            self.setupMenuBar()
            self.setupFloatingPanel()
            self.bindRuntime()
            self.runtime.start()
            NSApp.setActivationPolicy(UITestSupport.isEnabled ? .regular : .accessory)
            self.presentEnhancedCleanupPromptIfNeeded()
            if UITestSupport.shouldOpenSettingsOnLaunch() {
                SettingsWindowController.shared.show()
            }
        }
    }

    nonisolated func applicationDidBecomeActive(_ notification: Notification) {
        Task { @MainActor in
            self.runtime.appDidBecomeActive()
        }
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem?.button {
            button.title = ""
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            button.image = makeStatusBarImage()
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        runtimeStatusItem = NSMenuItem(title: "Yapper: Starting up...", action: nil, keyEquivalent: "")
        runtimeStatusItem?.isEnabled = false
        if let runtimeStatusItem {
            menu.addItem(runtimeStatusItem)
        }
        menu.addItem(.separator())

        let recordItem = NSMenuItem(
            title: "Record",
            action: #selector(toggleRecording),
            keyEquivalent: "r"
        )
        recordItem.keyEquivalentModifierMask = .command
        menu.addItem(recordItem)

        let prefsItem = NSMenuItem(
            title: "Settings",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        prefsItem.keyEquivalentModifierMask = .command
        menu.addItem(prefsItem)

        let enhancedCleanupItem = NSMenuItem(
            title: "Enhanced Cleanup...",
            action: #selector(openEnhancedCleanup),
            keyEquivalent: ""
        )
        menu.addItem(enhancedCleanupItem)

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

    private func bindRuntime() {
        runtime.onStateChange = { [weak self] state in
            self?.render(state)
        }
        modelStatusCancellable = LocalModelManager.shared.$status.sink { [weak self] _ in
            guard let self else { return }
            self.render(self.runtime.state)
        }
        render(runtime.state)
    }

    private func render(_ state: AppRuntimeState) {
        runtimeStatusItem?.title = statusLine(for: state)
        updateStatusButton(for: state)

        let displayState = state.displayRecordingState
        playSoundIfNeeded(for: displayState)
        if displayState == .idle || displayState == .loading {
            processingIndicatorTask?.cancel()
            processingIndicatorTask = nil
            floatingPanel?.hidePanel()
            return
        }

        if displayState == .processing {
            scheduleProcessingIndicator(for: state)
            return
        }

        processingIndicatorTask?.cancel()
        processingIndicatorTask = nil
        presentFloatingPanel(
            state: displayState,
            partialTranscript: state.partialTranscript,
            audioMeter: state.audioMeter
        )
    }

    private func statusLine(for state: AppRuntimeState) -> String {
        if !state.modelReady {
            return "Yapper: Loading model..."
        }

        switch state.recordingPhase {
        case .loading:
            return "Yapper: Loading model..."
        case .recording:
            return "Yapper: Listening"
        case .processing:
            return "Yapper: Processing..."
        case .completed(let outcome):
            return outcome == .clipboard ? "Yapper: Copied" : "Yapper: Inserted"
        case .cancelled:
            return "Yapper: Canceled"
        case .failed:
            return "Yapper: Failed"
        case .idle:
            break
        }

        switch LocalModelManager.shared.status {
        case .downloading(let progress):
            return "Yapper: Downloading cleanup \(Int(progress * 100))%"
        case .verifying:
            return "Yapper: Verifying cleanup..."
        case .failed:
            return "Yapper: Cleanup download failed"
        case .notInstalled, .ready:
            break
        }

        switch state.hotkeyMonitoringStatus {
        case .ready:
            return "Yapper: Ready"
        case .missingPermissions:
            var missing: [String] = []
            if state.permissions.accessibility != .authorized {
                missing.append("Accessibility")
            }
            if state.permissions.inputMonitoring != .authorized {
                missing.append("Input Monitoring")
            }
            return "Yapper: Missing \(missing.joined(separator: " + "))"
        case .temporarilyDisabled:
            return "Yapper: Recovering hotkeys..."
        case .failedToInstall:
            return "Yapper: Hotkeys unavailable"
        case .stopped:
            return "Yapper: Hotkeys stopped"
        }
    }

    private func updateStatusButton(for state: AppRuntimeState) {
        guard let button = statusItem?.button else { return }
        button.toolTip = statusLine(for: state)

        switch state.recordingPhase {
        case .recording:
            button.contentTintColor = .systemRed
        case .processing:
            button.contentTintColor = .controlAccentColor
        case .completed:
            button.contentTintColor = .systemGreen
        case .cancelled, .failed:
            button.contentTintColor = .systemOrange
        case .idle, .loading:
            switch LocalModelManager.shared.status {
            case .downloading, .verifying:
                button.contentTintColor = .controlAccentColor
            case .failed:
                button.contentTintColor = .systemOrange
            case .notInstalled, .ready:
                button.contentTintColor = nil
            }
        }
    }

    private func scheduleProcessingIndicator(for state: AppRuntimeState) {
        processingIndicatorTask?.cancel()
        processingIndicatorTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: Self.processingIndicatorDelay)
            guard let self,
                  self.runtime.state.displayRecordingState == .processing else { return }
            self.presentFloatingPanel(
                state: .processing,
                partialTranscript: self.runtime.state.partialTranscript,
                audioMeter: self.runtime.state.audioMeter
            )
        }
    }

    private func presentFloatingPanel(
        state: RecordingState,
        partialTranscript: String,
        audioMeter: AudioMeter
    ) {
        floatingPanel?.updateContent(
            state: state,
            partialTranscript: partialTranscript,
            audioMeter: audioMeter
        )
        floatingPanel?.showAtTopCenter()
    }

    private func playSoundIfNeeded(for displayState: RecordingState) {
        defer { previousSoundState = displayState }
        guard previousSoundState != displayState else { return }

        switch displayState {
        case .listening:
            SoundManager.shared.play(.recordingStart)
        case .inserted, .copied:
            SoundManager.shared.play(.processingComplete)
        case .failed:
            SoundManager.shared.play(.error)
        case .idle, .loading, .processing, .cancelled:
            break
        }
    }

    private func presentEnhancedCleanupPromptIfNeeded() {
        guard !UITestSupport.isEnabled,
              SettingsManager.shared.settings.enhancedCleanupPreference == .undecided else {
            return
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard SettingsManager.shared.settings.enhancedCleanupPreference == .undecided else { return }

            ModelDownloadWindowController.shared.show()
        }
    }

    private func makeStatusBarImage() -> NSImage? {
        if let assetImage = Bundle.module.image(forResource: "MenuBarIcon") {
            assetImage.isTemplate = true
            assetImage.size = NSSize(width: 18, height: 18)
            return assetImage
        }

        let filenames = ["icon.png", "icon@2x.png", "icon@3x.png"]
        let image = NSImage(size: NSSize(width: 18, height: 18))

        for filename in filenames {
            let parts = filename.split(separator: ".", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let resourceURL = Bundle.module.url(
                    forResource: parts[0],
                    withExtension: parts[1],
                    subdirectory: "MenuBarResources"
                  ),
                  let representation = NSImageRep(contentsOf: resourceURL) else {
                continue
            }
            image.addRepresentation(representation)
        }

        guard !image.representations.isEmpty else { return nil }
        image.isTemplate = true
        return image
    }

    @objc private func toggleRecording() {
        runtime.handleMenuToggleRecording()
    }

    @objc private func openPreferences() {
        SettingsWindowController.shared.show()
    }

    @objc private func openEnhancedCleanup() {
        ModelDownloadWindowController.shared.show()
    }

    @objc private func quitApp() {
        runtime.stop()
        NSApp.terminate(nil)
    }
}
