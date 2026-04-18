import Foundation
import AppKit
import ApplicationServices

final class TextInserter: @unchecked Sendable {

    // The string value of kAXTrustedCheckOptionPrompt, hardcoded to avoid
    // Swift 6 "concurrency-unsafe mutable state" errors on the C global var.
    private static let axTrustedKey = "AXTrustedCheckOptionPrompt"

    func insert(text: String, method: InsertionMethod = .axuiElement) {
        guard !text.isEmpty else { return }

        switch method {
        case .axuiElement:
            if !insertViaAccessibility(text: text) {
                insertViaClipboard(text: text)
            }
        case .clipboard:
            insertViaClipboard(text: text)
        }
    }

    // MARK: - Accessibility (AXUIElement)

    private func insertViaAccessibility(text: String) -> Bool {
        guard checkAccessibilityPermission() else { return false }
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)

        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            appElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedRef
        ) == .success, let focused = focusedRef else {
            return false
        }

        let element = focused as! AXUIElement

        // Get current value and append
        var valueRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef)
        let existing = (valueRef as? String) ?? ""
        let newValue = existing + text

        let result = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            newValue as CFTypeRef
        )
        return result == .success
    }

    // MARK: - Clipboard Fallback

    private func insertViaClipboard(text: String) {
        let pasteboard = NSPasteboard.general
        let saved = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        simulatePaste()

        // Restore original clipboard after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let saved {
                pasteboard.clearContents()
                pasteboard.setString(saved, forType: .string)
            }
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        // Virtual key 0x09 = 'v'
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false) else {
            return
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    // MARK: - Permissions

    func checkAccessibilityPermission() -> Bool {
        let opts = [Self.axTrustedKey: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    func requestAccessibilityPermission() {
        let opts = [Self.axTrustedKey: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }
}
