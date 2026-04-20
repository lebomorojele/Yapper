import Foundation
import AppKit
import ApplicationServices

final class TextInserter: @unchecked Sendable {

    // The string value of kAXTrustedCheckOptionPrompt, hardcoded to avoid
    // Swift 6 "concurrency-unsafe mutable state" errors on the C global var.
    static let axTrustedKeyForPrompt = "AXTrustedCheckOptionPrompt"

    func insert(text: String, method: InsertionMethod = .axuiElement) -> InsertionOutcome {
        guard !text.isEmpty else { return .accessibility }

        switch method {
        case .axuiElement:
            if insertViaAccessibility(text: text) {
                return .accessibility
            }
            insertViaClipboard(text: text)
            return .clipboard
        case .clipboard:
            insertViaClipboard(text: text)
            return .clipboard
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

        // Prefer replacing the selected range when the focused element exposes one.
        var valueRef: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &valueRef)
        let existing = (valueRef as? String) ?? ""

        let newValue: String
        if let selectedRange = selectedTextRange(for: element),
           let swiftRange = Range(NSRange(location: selectedRange.location, length: selectedRange.length), in: existing) {
            newValue = existing.replacingCharacters(in: swiftRange, with: text)
        } else {
            newValue = existing + text
        }

        let result = AXUIElementSetAttributeValue(
            element,
            kAXValueAttribute as CFString,
            newValue as CFTypeRef
        )

        guard result == .success else {
            return false
        }

        if let selectedRange = selectedTextRange(for: element) {
            let insertionLocation = selectedRange.location + text.utf16.count
            setSelectedTextRange(
                for: element,
                range: CFRange(location: insertionLocation, length: 0)
            )
        }

        return true
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

    private func selectedTextRange(for element: AXUIElement) -> CFRange? {
        var selectedRangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            &selectedRangeRef
        ) == .success,
        let axValue = selectedRangeRef as! AXValue?,
        AXValueGetType(axValue) == .cfRange else {
            return nil
        }

        var range = CFRange()
        guard AXValueGetValue(axValue, .cfRange, &range) else {
            return nil
        }
        return range
    }

    private func setSelectedTextRange(for element: AXUIElement, range: CFRange) {
        var mutableRange = range
        guard let axRange = AXValueCreate(.cfRange, &mutableRange) else { return }
        AXUIElementSetAttributeValue(
            element,
            kAXSelectedTextRangeAttribute as CFString,
            axRange
        )
    }

    // MARK: - Permissions

    func checkAccessibilityPermission() -> Bool {
        let opts = [Self.axTrustedKeyForPrompt: false] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    func requestAccessibilityPermission() {
        let opts = [Self.axTrustedKeyForPrompt: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }
}
