import SwiftUI
import AppKit

final class FloatingPanel: NSPanel {
    private var hostingView: NSHostingView<PillContentView>?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 317, height: 40),
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
        hostingView?.frame = NSRect(x: 0, y: 0, width: 317, height: 48)
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

        let targetWidth: CGFloat = 317
        let targetHeight: CGFloat = showOptions ? 124 : 48
        hostingView?.frame = NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight)

        if abs(frame.height - targetHeight) > 1 || abs(frame.width - targetWidth) > 1 {
            var newFrame = frame
            let heightDiff = targetHeight - newFrame.height
            let widthDiff = targetWidth - newFrame.width
            
            newFrame.size.height = targetHeight
            newFrame.size.width = targetWidth
            newFrame.origin.y -= heightDiff
            newFrame.origin.x -= widthDiff / 2 // Center horizontally when expanding

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.5
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().setFrame(newFrame, display: true)
            }
        }
    }

    func showAtTopCenter() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let panelWidth: CGFloat = 317
        let panelHeight: CGFloat = 48

        let x = visibleFrame.midX - panelWidth / 2
        let y = visibleFrame.maxY - panelHeight - 50

        setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        orderFront(nil)
    }

    func hidePanel() {
        orderOut(nil)
    }
}
