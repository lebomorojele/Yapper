import SwiftUI
import AppKit

final class FloatingPanel: NSPanel {
    private var hostingView: NSHostingView<PillContentView>?
    private let compactFrame = NSSize(width: 317, height: 38)
    private let optionsFrame = NSSize(width: 372, height: 98)

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 317, height: 38),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        configurePanel()
        setupContent()
    }

    // MARK: - Configuration

    private func configurePanel() {
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = true // Allows dragging anywhere on the background
        hidesOnDeactivate = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
    }

    private func setupContent() {
        let view = PillContentView()
        hostingView = NSHostingView(rootView: view)
        hostingView?.wantsLayer = true
        hostingView?.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView?.frame = NSRect(origin: .zero, size: compactFrame)
        hostingView?.autoresizingMask = [.width, .height]
        self.contentView = hostingView
    }

    // MARK: - Public API

    func updateContent(
        state: RecordingState,
        partialTranscript: String,
        showOptions: Bool,
        audioLevel: Float = 0,
        recordingStartTime: Date? = nil,
        onOptionSelected: @escaping (SmartModeOption) -> Void
    ) {
        let view = PillContentView(
            state: state,
            partialTranscript: partialTranscript,
            showOptions: showOptions,
            audioLevel: audioLevel,
            recordingStartTime: recordingStartTime,
            onOptionSelected: onOptionSelected
        )
        hostingView?.rootView = view
        hostingView?.wantsLayer = true
        hostingView?.layer?.backgroundColor = NSColor.clear.cgColor

        let targetSize = showOptions ? optionsFrame : compactFrame
        hostingView?.frame = NSRect(origin: .zero, size: targetSize)

        if abs(frame.height - targetSize.height) > 1 || abs(frame.width - targetSize.width) > 1 {
            var newFrame = frame
            let heightDiff = targetSize.height - newFrame.height
            let widthDiff = targetSize.width - newFrame.width
            
            newFrame.size.height = targetSize.height
            newFrame.size.width = targetSize.width
            newFrame.origin.y -= heightDiff
            newFrame.origin.x -= widthDiff / 2

            setFrame(newFrame, display: true)
        }
    }

    func showAtTopCenter() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let panelWidth = compactFrame.width
        let panelHeight = compactFrame.height

        let x = visibleFrame.midX - panelWidth / 2
        let y = visibleFrame.maxY - panelHeight - 50

        setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        orderFront(nil)
    }

    func hidePanel() {
        orderOut(nil)
    }
}
