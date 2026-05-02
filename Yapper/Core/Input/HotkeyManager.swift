import Foundation
import AppKit
import CoreGraphics

protocol HotkeyEventTapControlling: AnyObject {
    func install(callback: CGEventTapCallBack, userInfo: UnsafeMutableRawPointer?) -> Bool
    func setEnabled(_ enabled: Bool)
    func uninstall()
}

final class SystemHotkeyEventTapController: HotkeyEventTapControlling {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func install(callback: CGEventTapCallBack, userInfo: UnsafeMutableRawPointer?) -> Bool {
        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: userInfo
        ) else {
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        setEnabled(true)
        return true
    }

    func setEnabled(_ enabled: Bool) {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: enabled)
    }

    func uninstall() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }
}

final class HotkeyManager: @unchecked Sendable {
    private static let fnKeyCode: Int64 = 63

    var onGesture: (@Sendable (InputGesture) -> Void)?
    var onStatusChanged: (@Sendable (HotkeyMonitoringStatus) -> Void)?

    private let eventTapController: HotkeyEventTapControlling
    private let gestureInterpreter: GestureInterpreter

    private var fnKeyDown = false
    private var desiredMonitoring = false
    private var hasInstalledTap = false
    private var permissionSnapshot = PermissionSnapshot()

    private(set) var monitoringStatus: HotkeyMonitoringStatus = .stopped {
        didSet {
            guard oldValue != monitoringStatus else { return }
            onStatusChanged?(monitoringStatus)
        }
    }

    init(
        eventTapController: HotkeyEventTapControlling = SystemHotkeyEventTapController(),
        gestureInterpreter: GestureInterpreter = GestureInterpreter()
    ) {
        self.eventTapController = eventTapController
        self.gestureInterpreter = gestureInterpreter
        self.gestureInterpreter.onGesture = { [weak self] gesture in
            self?.onGesture?(gesture)
        }
    }

    deinit {
        stop()
    }

    func start() {
        desiredMonitoring = true
        refreshMonitoringState()
    }

    func stop() {
        desiredMonitoring = false
        teardownEventTap()
        updateStatus(.stopped)
    }

    func updatePermissionSnapshot(_ snapshot: PermissionSnapshot) {
        permissionSnapshot = snapshot
        refreshMonitoringState()
    }

    func refreshMonitoringState() {
        guard desiredMonitoring else {
            teardownEventTap()
            updateStatus(.stopped)
            return
        }

        guard permissionSnapshot.hasHotkeyPermissions else {
            teardownEventTap()
            updateStatus(.missingPermissions)
            return
        }

        guard !hasInstalledTap else {
            updateStatus(.ready)
            return
        }

        let installed = eventTapController.install(
            callback: hotkeyEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )

        hasInstalledTap = installed
        if installed {
            print("[HotkeyManager] Event tap installed successfully")
            updateStatus(.ready)
        } else {
            print("[HotkeyManager] Failed to create event tap")
            updateStatus(.failedToInstall)
        }
    }

    func handleEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            updateStatus(.temporarilyDisabled)
            eventTapController.setEnabled(true)
            refreshMonitoringState()
            return Unmanaged.passRetained(event)
        }

        guard type == .flagsChanged else {
            return Unmanaged.passRetained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == Self.fnKeyCode else {
            return Unmanaged.passRetained(event)
        }

        let currentlyDown = event.flags.contains(.maskSecondaryFn)
        if currentlyDown && !fnKeyDown {
            fnKeyDown = true
            gestureInterpreter.keyDown()
            return nil
        }

        if !currentlyDown && fnKeyDown {
            fnKeyDown = false
            gestureInterpreter.keyUp()
            return nil
        }

        return Unmanaged.passRetained(event)
    }

    private func teardownEventTap() {
        guard hasInstalledTap else { return }
        eventTapController.uninstall()
        hasInstalledTap = false
        fnKeyDown = false
    }

    private func updateStatus(_ status: HotkeyMonitoringStatus) {
        monitoringStatus = status
    }
}

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
