import SwiftUI
import AppKit

final class FloatingPanel: NSPanel {
    private var hostingView: NSHostingView<PillContentView>?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 48),
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
        isMovableByWindowBackground = false
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
        hostingView?.frame = NSRect(x: 0, y: 0, width: 260, height: 48)
        self.contentView = hostingView
    }

    // MARK: - Public API

    func updateContent(
        state: RecordingState,
        partialTranscript: String,
        showOptions: Bool,
        audioLevel: Float = 0,
        onOptionSelected: @escaping (SmartModeOption) -> Void
    ) {
        let view = PillContentView(
            state: state,
            partialTranscript: partialTranscript,
            showOptions: showOptions,
            audioLevel: audioLevel,
            onOptionSelected: onOptionSelected
        )
        hostingView?.rootView = view

        // Animate panel height for options
        let targetHeight: CGFloat = showOptions ? 200 : 48

        if abs(frame.height - targetHeight) > 1 {
            var newFrame = frame
            let diff = targetHeight - newFrame.height
            newFrame.size.height = targetHeight
            newFrame.origin.y -= diff

            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
                self.animator().setFrame(newFrame, display: true)
            }
        }
    }

    func showAtTopCenter() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let panelWidth: CGFloat = 260
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
