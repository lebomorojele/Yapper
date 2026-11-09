import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let processingIndicatorDelay: Duration = .milliseconds(180)

    private var statusItem: NSStatusItem?
    private var runtimeStatusItem: NSMenuItem?
    private var recordMenuItem: NSMenuItem?
    private var copyMenuItem: NSMenuItem?
    private var retryMenuItem: NSMenuItem?
    private var enhancedCleanupMenuItem: NSMenuItem?
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
            SparkleUpdateController.shared.start()
            if UITestSupport.shouldOpenWelcomeOnLaunch() || (!UITestSupport.isEnabled && !UserDefaults.standard.bool(forKey: WelcomeWindowController.completedKey)) {
                self.openWelcome()
            }
            if !UITestSupport.isEnabled { self.runtime.start() }
            NSApp.setActivationPolicy(UITestSupport.isEnabled ? .regular : .accessory)
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
            button.contentTintColor = nil
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
        recordMenuItem = recordItem
        menu.addItem(recordItem)
        let cancelItem = NSMenuItem(title: "Cancel Recording", action: #selector(cancelRecording), keyEquivalent: ".")
        cancelItem.keyEquivalentModifierMask = .command
        menu.addItem(cancelItem)
        copyMenuItem = NSMenuItem(title: "Copy Last Transcript", action: #selector(copyLastTranscript), keyEquivalent: "")
        if let copyMenuItem { menu.addItem(copyMenuItem) }
        retryMenuItem = NSMenuItem(title: "Retry Speech Model Download", action: #selector(retryModelLoading), keyEquivalent: "")
        if let retryMenuItem { menu.addItem(retryMenuItem) }
        menu.addItem(NSMenuItem(title: "Setup & Permissions…", action: #selector(openWelcome), keyEquivalent: ""))

        let prefsItem = NSMenuItem(
            title: "Settings",
            action: #selector(openPreferences),
            keyEquivalent: ","
        )
        prefsItem.keyEquivalentModifierMask = .command
        menu.addItem(prefsItem)

        enhancedCleanupMenuItem = NSMenuItem(
            title: "Enhanced Cleanup...",
            action: #selector(openEnhancedCleanup),
            keyEquivalent: ""
        )
        if let enhancedCleanupMenuItem {
            menu.addItem(enhancedCleanupMenuItem)
        }

        let updateItem = NSMenuItem(
            title: "Check for Updates...",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.isHidden = !SparkleUpdateController.shared.isAvailable
        menu.addItem(updateItem)

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
        updateEnhancedCleanupMenuItem()
        updateStatusButton(for: state)
        WelcomeWindowController.shared.update(state)
        recordMenuItem?.title = state.recordingPhase == .recording ? "Finish Recording" : "Record"
        copyMenuItem?.isEnabled = !runtime.lastTranscript.isEmpty
        retryMenuItem?.isHidden = state.modelReady || state.recordingPhase == .loading

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
        if case .failed(let message) = state.recordingPhase {
            return "Yapper: \(message ?? "Something went wrong. Try again.")"
        }
        if !state.modelReady {
            return "Yapper: Preparing speech model \(Int(state.modelDownloadProgress * 100))%"
        }

        switch state.recordingPhase {
        case .loading:
            return "Yapper: Preparing speech model \(Int(state.modelDownloadProgress * 100))%"
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
        button.contentTintColor = nil
    }

    private func scheduleProcessingIndicator(for state: AppRuntimeState) {
        processingIndicatorTask?.cancel()
        processingIndicatorTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: Self.processingIndicatorDelay) } catch { return }
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

    private func updateEnhancedCleanupMenuItem() {
        guard let enhancedCleanupMenuItem else { return }

        switch LocalModelManager.shared.status {
        case .notInstalled:
            switch SettingsManager.shared.settings.enhancedCleanupPreference {
            case .undecided:
                enhancedCleanupMenuItem.title = "Enhanced Cleanup Recommended..."
                enhancedCleanupMenuItem.isHidden = false
                enhancedCleanupMenuItem.isEnabled = true
            case .enabled:
                enhancedCleanupMenuItem.title = "Download Enhanced Cleanup..."
                enhancedCleanupMenuItem.isHidden = false
                enhancedCleanupMenuItem.isEnabled = true
            case .declined:
                enhancedCleanupMenuItem.isHidden = true
            }
        case .downloading(let progress):
            enhancedCleanupMenuItem.title = "Enhanced Cleanup Downloading \(Int(progress * 100))%..."
            enhancedCleanupMenuItem.isHidden = false
            enhancedCleanupMenuItem.isEnabled = true
        case .verifying:
            enhancedCleanupMenuItem.title = "Enhanced Cleanup Verifying..."
            enhancedCleanupMenuItem.isHidden = false
            enhancedCleanupMenuItem.isEnabled = true
        case .ready:
            enhancedCleanupMenuItem.isHidden = true
        case .failed:
            enhancedCleanupMenuItem.title = "Enhanced Cleanup Needs Attention..."
            enhancedCleanupMenuItem.isHidden = false
            enhancedCleanupMenuItem.isEnabled = true
        }
    }

    private func makeStatusBarImage() -> NSImage? {
        let filenames = ["icon.png", "icon@2x.png", "icon@3x.png"]
        let image = NSImage(size: NSSize(width: 18, height: 18))

        for filename in filenames {
            let parts = filename.split(separator: ".", maxSplits: 1).map(String.init)
            guard parts.count == 2,
                  let resourceURL = AppResourceLocator.url(
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

    @objc private func cancelRecording() { runtime.cancelRecording() }

    @objc private func copyLastTranscript() {
        guard !runtime.lastTranscript.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(runtime.lastTranscript, forType: .string)
    }

    @objc private func retryModelLoading() { runtime.retryModelLoading() }

    @objc private func openWelcome() {
        WelcomeWindowController.shared.show { [weak self] in self?.runtime.retryModelLoading() }
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

    @objc private func checkForUpdates() {
        SparkleUpdateController.shared.checkForUpdates()
    }

    @objc private func quitApp() {
        runtime.stop()
        NSApp.terminate(nil)
    }
}
