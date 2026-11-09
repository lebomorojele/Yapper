import Foundation

enum UITestLaunchOption {
    static let enabled = "YAPPER_UI_TEST_MODE"
    static let openWelcome = "YAPPER_OPEN_WELCOME_ON_LAUNCH"
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

    static func shouldOpenWelcomeOnLaunch() -> Bool {
        isEnabled && ProcessInfo.processInfo.environment[UITestLaunchOption.openWelcome] == "1"
    }

    static func shouldOpenSettingsOnLaunch() -> Bool {
        ProcessInfo.processInfo.environment[UITestLaunchOption.openSettings] == "1"
    }
}
