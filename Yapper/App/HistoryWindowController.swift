import AppKit
import SwiftUI

final class HistoryWindowController: NSWindowController {
    static let shared = HistoryWindowController()

    private init() {
        let view = HistoryView()
        let hostingController = NSHostingController(rootView: view)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 560),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "History"
        window.center()
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        window.toolbarStyle = .unified

        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
