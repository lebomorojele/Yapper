import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var runtimeStatusItem: NSMenuItem?
    private var floatingPanel: FloatingPanel?
    private var smartSelectionKeyMonitor: Any?

    private let runtime = AppRuntimeCoordinator(
        dictationController: DictationController(
            audioEngine: AudioEngine(),
            transcriber: ParakeetTranscriber(),
            llmProcessor: LLMProcessor(),
            textInserter: TextInserter()
        ),
        hotkeyManager: HotkeyManager()
    )

    nonisolated func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            self.setupMenuBar()
            self.setupFloatingPanel()
            self.bindRuntime()
            self.runtime.start()
            NSApp.setActivationPolicy(.accessory)
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
            let iconPath = Bundle.main.path(forResource: "icon1", ofType: "png")
                ?? NSHomeDirectory() + "/Documents/projects/Yapper/icon1.png"
            button.image = NSImage(contentsOfFile: iconPath)
            button.image?.size = NSSize(width: 18, height: 18)
            button.image?.isTemplate = true
        }

        let menu = NSMenu()
        runtimeStatusItem = NSMenuItem(title: "Status: Starting up...", action: nil, keyEquivalent: "")
        runtimeStatusItem?.isEnabled = false
        if let runtimeStatusItem {
            menu.addItem(runtimeStatusItem)
        }
        menu.addItem(.separator())

        let recordItem = NSMenuItem(
            title: "Start Recording",
            action: #selector(toggleRecording),
            keyEquivalent: "r"
        )
        recordItem.keyEquivalentModifierMask = .command
        menu.addItem(recordItem)

        menu.addItem(.separator())

        let historyItem = NSMenuItem(
            title: "History...",
            action: #selector(openHistory),
            keyEquivalent: "h"
        )
        historyItem.keyEquivalentModifierMask = .command
        menu.addItem(historyItem)

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

        statusMenu = menu
        statusItem?.menu = menu
    }

    private func setupFloatingPanel() {
        floatingPanel = FloatingPanel()
    }

    private func bindRuntime() {
        runtime.onStateChange = { [weak self] state in
            self?.render(state)
        }
        render(runtime.state)
    }

    private func render(_ state: AppRuntimeState) {
        runtimeStatusItem?.title = statusLine(for: state)

        if state.showsSmartOptions {
            installSmartSelectionKeyMonitor()
        } else {
            removeSmartSelectionKeyMonitor()
        }

        if state.displayRecordingState == .idle && !state.showsSmartOptions {
            floatingPanel?.hidePanel()
            return
        }

        floatingPanel?.showAtTopCenter()
        floatingPanel?.updateContent(
            state: state.displayRecordingState,
            partialTranscript: state.partialTranscript,
            showOptions: state.showsSmartOptions,
            audioMeter: state.audioMeter,
            recordingStartTime: state.recordingStartTime,
            onOptionSelected: { [weak self] option in
                self?.runtime.selectSmartMode(option)
            }
        )
    }

    private func statusLine(for state: AppRuntimeState) -> String {
        if !state.modelReady {
            return "Status: Loading model..."
        }

        switch state.hotkeyMonitoringStatus {
        case .ready:
            return "Status: Hotkeys ready"
        case .missingPermissions:
            var missing: [String] = []
            if state.permissions.accessibility != .authorized {
                missing.append("Accessibility")
            }
            if state.permissions.inputMonitoring != .authorized {
                missing.append("Input Monitoring")
            }
            return "Status: Missing \(missing.joined(separator: " + "))"
        case .temporarilyDisabled:
            return "Status: Recovering hotkeys..."
        case .failedToInstall:
            return "Status: Hotkeys unavailable"
        case .stopped:
            return "Status: Hotkeys stopped"
        }
    }

    private func installSmartSelectionKeyMonitor() {
        guard smartSelectionKeyMonitor == nil else { return }

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
        switch event.charactersIgnoringModifiers {
        case "1":
            runtime.selectSmartMode(.slack)
        case "2":
            runtime.selectSmartMode(.chat)
        case "3":
            runtime.selectSmartMode(.email)
        case "4":
            runtime.selectSmartMode(.prompt)
        default:
            break
        }
    }

    @objc private func toggleRecording() {
        runtime.handleMenuToggleRecording()
    }

    @objc private func openPreferences() {
        SettingsWindowController.shared.show()
    }

    @objc private func openHistory() {
        HistoryWindowController.shared.show()
    }

    #if DEBUG
    @objc private func openDesignCatalog() {
        DesignCatalogWindowController.shared.show()
    }
    #endif

    @objc private func quitApp() {
        removeSmartSelectionKeyMonitor()
        runtime.stop()
        NSApp.terminate(nil)
    }
}
