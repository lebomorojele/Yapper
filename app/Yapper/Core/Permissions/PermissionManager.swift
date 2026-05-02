import Foundation
import AVFoundation
import ApplicationServices
import AppKit

enum PermissionKind: String, Sendable {
    case microphone = "Microphone"
    case accessibility = "Accessibility"
    case inputMonitoring = "Input Monitoring"
}

final class PermissionManager: @unchecked Sendable {
    static let shared = PermissionManager()
    
    private init() {}
    
    var isMicrophoneAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }
    
    var isAccessibilityAuthorized: Bool {
        AXIsProcessTrusted()
    }

    var isInputMonitoringAuthorized: Bool {
        CGPreflightListenEventAccess()
    }

    func snapshot() -> PermissionSnapshot {
        PermissionSnapshot(
            microphone: microphoneStatus(),
            accessibility: isAccessibilityAuthorized ? .authorized : .denied,
            inputMonitoring: isInputMonitoringAuthorized ? .authorized : .denied
        )
    }

    func microphoneStatus() -> PermissionAuthorizationStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .denied
        }
    }

    func requestMicrophonePermission() async -> PermissionAuthorizationStatus {
        _ = await AVCaptureDevice.requestAccess(for: .audio)
        return microphoneStatus()
    }

    func requestAccessibilityPermission() {
        let opts = [TextInserter.axTrustedKeyForPrompt: true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    func requestInputMonitoringPermission() {
        _ = CGRequestListenEventAccess()
    }
    
    func openSystemSettings(for permission: PermissionKind) {
        let urlString: String
        switch permission {
        case .microphone:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case .accessibility:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        case .inputMonitoring:
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
