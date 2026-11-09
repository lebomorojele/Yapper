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

        XCTAssertTrue(element("settings.root").waitForExistence(timeout: 10))
        XCTAssertTrue(element("settings.pane.general").exists)

        element("settings.sidebar.audio").click()
        XCTAssertTrue(element("settings.pane.audio").waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Input Device"].exists)

        element("settings.sidebar.keyboard").click()
        XCTAssertTrue(element("settings.pane.keyboard").waitForExistence(timeout: 2))

        element("settings.sidebar.about").click()
        XCTAssertTrue(element("settings.pane.about").waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Version 0.2.0"].exists)
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
