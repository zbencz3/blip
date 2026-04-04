import XCTest

final class BlipUITests: XCTestCase {

    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()

        // Wait for app to load
        sleep(2)

        // Handle notification permission dialog if present
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowButton = springboard.buttons["Allow"]
        if allowButton.waitForExistence(timeout: 3) {
            allowButton.tap()
        }
        sleep(1)
    }

    func testScreenshot_01_Home() throws {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "01_home"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testScreenshot_02_Settings() throws {
        // Tap settings gear icon (second button in nav bar)
        let buttons = app.buttons.allElementsBoundByIndex
        // The settings button is the rightmost button at top
        let settingsButton = app.buttons["gearshape.fill"]
        if settingsButton.waitForExistence(timeout: 3) {
            settingsButton.tap()
        } else if buttons.count > 1 {
            buttons[1].tap()
        }
        sleep(1)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "02_settings"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testScreenshot_03_Webhooks() throws {
        // Navigate to Settings first
        let settingsButton = app.buttons["gearshape.fill"]
        if settingsButton.waitForExistence(timeout: 3) {
            settingsButton.tap()
        } else {
            app.buttons.element(boundBy: 1).tap()
        }
        sleep(1)

        // Tap Webhooks
        let webhooksButton = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Webhook'")).firstMatch
        if webhooksButton.waitForExistence(timeout: 3) {
            webhooksButton.tap()
        }
        sleep(1)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "03_webhooks"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testScreenshot_04_RecentNotifications() throws {
        // Tap clock/history icon (first button in nav bar)
        let historyButton = app.buttons["clock.arrow.circlepath"]
        if historyButton.waitForExistence(timeout: 3) {
            historyButton.tap()
        } else {
            app.buttons.element(boundBy: 0).tap()
        }
        sleep(1)

        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "04_recent_notifications"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
