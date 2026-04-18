import Foundation
import AppKit
import CoreGraphics

final class HotkeyManager: @unchecked Sendable {
    var onGesture: (@Sendable (InputGesture) -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let gestureInterpreter = GestureInterpreter()
    private var fnKeyDown = false

    init() {}

    deinit {
        stop()
    }

    func start() {
        gestureInterpreter.onGesture = { [weak self] gesture in
            self?.onGesture?(gesture)
        }
        setupEventTap()
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    // MARK: - Event Tap Setup

    private func setupEventTap() {
        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[HotkeyManager] Failed to create event tap — Accessibility permission required")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[HotkeyManager] Event tap installed")
    }

    // MARK: - Event Handling

    func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable tap if system disabled it
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        guard type == .flagsChanged else {
            return Unmanaged.passRetained(event)
        }

        let flags = event.flags
        let currentlyDown = flags.contains(.maskSecondaryFn)

        if currentlyDown && !fnKeyDown {
            fnKeyDown = true
            gestureInterpreter.keyDown()
            return nil  // consume fn-down event
        } else if !currentlyDown && fnKeyDown {
            fnKeyDown = false
            gestureInterpreter.keyUp()
            return nil  // consume fn-up event
        }

        return Unmanaged.passRetained(event)
    }
}

// MARK: - C Callback (file-scope free function)

private func hotkeyEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo else { return Unmanaged.passRetained(event) }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
    return manager.handleEvent(type: type, event: event)
}
