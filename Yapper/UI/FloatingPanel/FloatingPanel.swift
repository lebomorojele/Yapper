import SwiftUI
import AppKit

private final class DraggableHostingView<Content: View>: NSHostingView<Content> {
    var allowsWindowDrag = true

    override var mouseDownCanMoveWindow: Bool {
        allowsWindowDrag
    }

    override func mouseDown(with event: NSEvent) {
        guard allowsWindowDrag else {
            super.mouseDown(with: event)
            return
        }
        window?.performDrag(with: event)
    }
}

final class FloatingPanel: NSPanel {
    private var hostingView: DraggableHostingView<PillContentView>?
    private var panelFrame = NSSize(width: 72, height: PillContentView.preferredHeight)

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: PillContentView.preferredHeight),
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
        hasShadow = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
    }

    private func setupContent() {
        let view = PillContentView()
        hostingView = DraggableHostingView(rootView: view)
        hostingView?.wantsLayer = true
        hostingView?.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView?.allowsWindowDrag = true
        hostingView?.frame = NSRect(origin: .zero, size: panelFrame)
        hostingView?.autoresizingMask = [.width, .height]
        self.contentView = hostingView
    }

    // MARK: - Public API

    func updateContent(
        state: RecordingState,
        partialTranscript: String,
        audioMeter: AudioMeter = .empty
    ) {
        let resolvedWidth = PillContentView.resolvedWidth(
            currentWidth: panelFrame.width,
            state: state,
            partialTranscript: partialTranscript
        )
        panelFrame = NSSize(width: resolvedWidth, height: PillContentView.preferredHeight)

        let view = PillContentView(
            state: state,
            partialTranscript: partialTranscript,
            audioMeter: audioMeter,
            resolvedWidth: resolvedWidth
        )
        hostingView?.rootView = view
        hostingView?.wantsLayer = true
        hostingView?.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView?.allowsWindowDrag = true

        hostingView?.frame = NSRect(origin: .zero, size: panelFrame)
        contentView?.frame = NSRect(origin: .zero, size: panelFrame)
    }

    func showAtTopCenter() {
        guard let screen = NSScreen.main else { return }
        let visibleFrame = screen.visibleFrame
        let panelWidth = panelFrame.width
        let panelHeight = panelFrame.height

        let x = visibleFrame.midX - panelWidth / 2
        let y = visibleFrame.maxY - panelHeight - 50

        setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
        orderFront(nil)
    }

    func hidePanel() {
        orderOut(nil)
    }
}
