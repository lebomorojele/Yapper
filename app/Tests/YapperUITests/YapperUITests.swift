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

        XCTAssertTrue(app.otherElements["settings.root"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["settings.pane.general"].exists)

        app.staticTexts["Audio"].click()
        XCTAssertTrue(app.otherElements["settings.pane.audio"].waitForExistence(timeout: 2))

        app.staticTexts["Keyboard"].click()
        XCTAssertTrue(app.otherElements["settings.pane.keyboard"].waitForExistence(timeout: 2))
    }
}
