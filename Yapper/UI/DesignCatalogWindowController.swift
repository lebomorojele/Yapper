import AppKit
import SwiftUI

#if DEBUG
final class DesignCatalogWindowController: NSWindowController {
    static let shared = DesignCatalogWindowController()

    private init() {
        let view = DesignCatalogView()
        let hostingController = NSHostingController(rootView: view)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 450),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "UI Design Catalog (Debug)"
        window.center()
        window.contentViewController = hostingController
        window.isReleasedWhenClosed = false
        
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
#endif
