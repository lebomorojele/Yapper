import Foundation
import AVFoundation
import ApplicationServices
import AppKit

final class PermissionManager: @unchecked Sendable {
    static let shared = PermissionManager()
    
    private init() {}
    
    var isMicrophoneAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }
    
    var isAccessibilityAuthorized: Bool {
        AXIsProcessTrusted()
    }
    
    func openSystemSettings(for permission: String) {
        let urlString: String
        switch permission {
        case "Microphone":
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
        case "Accessibility":
            urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        default:
            urlString = "x-apple.systempreferences:com.apple.preference.security"
        }
        
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
