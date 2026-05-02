import Foundation

enum UITestLaunchOption {
    static let enabled = "YAPPER_UI_TEST_MODE"
    static let openSettings = "YAPPER_OPEN_SETTINGS_ON_LAUNCH"
}

enum UITestSupport {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.environment[UITestLaunchOption.enabled] == "1"
    }

    static func configureIfNeeded() {
        guard isEnabled else { return }
        UserDefaults.standard.set(false, forKey: "NSQuitAlwaysKeepsWindows")
    }

    static func shouldOpenSettingsOnLaunch() -> Bool {
        ProcessInfo.processInfo.environment[UITestLaunchOption.openSettings] == "1"
    }
}
