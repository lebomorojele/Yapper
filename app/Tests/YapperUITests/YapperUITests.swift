import XCTest

@MainActor
final class YapperUITests: XCTestCase {
    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testSettingsWindowOpensAndSwitchesPanes() throws {
        app.launchEnvironment["YAPPER_UI_TEST_MODE"] = "1"
        app.launchEnvironment["YAPPER_OPEN_SETTINGS_ON_LAUNCH"] = "1"
        app.launch()

        XCTAssertTrue(app.windows.firstMatch.waitForExistence(timeout: 10))
        XCTAssertTrue(labeled("Clean punctuation and casing").exists)

        app.staticTexts["Audio"].firstMatch.click()
        XCTAssertTrue(labeled("Auto-stop when quiet").waitForExistence(timeout: 2))

        app.staticTexts["Keyboard"].firstMatch.click()
        XCTAssertTrue(app.staticTexts["Fn / Globe"].waitForExistence(timeout: 2))

        app.staticTexts["About"].firstMatch.click()
        XCTAssertTrue(app.staticTexts["Version 0.2.0"].waitForExistence(timeout: 2))
        keepScreenshot("Native settings")
    }

    func testWelcomeExplainsPermissionsAndWaitsForModelReadiness() throws {
        app.launchEnvironment["YAPPER_UI_TEST_MODE"] = "1"
        app.launchEnvironment["YAPPER_OPEN_WELCOME_ON_LAUNCH"] = "1"
        app.launch()

        XCTAssertTrue(element("welcome.root").waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Microphone"].exists)
        XCTAssertTrue(app.staticTexts["Accessibility"].exists)
        XCTAssertTrue(app.staticTexts["Input Monitoring"].exists)
        XCTAssertFalse(app.buttons["Let's yap"].isEnabled)
        keepScreenshot("Native setup")
    }

    private func labeled(_ label: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    private func element(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func keepScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
