import XCTest

final class LockedInUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testThreeTabNavigationStructure() throws {
        let app = launchReadyApp()

        XCTAssertTrue(app.tabBars.buttons["Home"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.tabBars.buttons["Protocols"].exists)
        XCTAssertTrue(app.tabBars.buttons["LifeScore"].exists)
        XCTAssertEqual(app.tabBars.buttons.count, 3)
    }

    @MainActor
    func testLockLauncherOpensAndClosesOverlay() throws {
        let app = launchReadyApp()

        app.buttons["home.lockLauncher"].tap()

        XCTAssertTrue(app.navigationBars["LOCK"].waitForExistence(timeout: 2))

        let closeButton = app.buttons["lock.closeButton"]
        XCTAssertTrue(closeButton.exists)
        closeButton.tap()

        XCTAssertFalse(closeButton.waitForExistence(timeout: 2))
    }

    @MainActor
    func testNameTapOpensSettings() throws {
        let app = launchReadyApp()

        let nameButton = app.buttons["home.nameButton"]
        XCTAssertTrue(nameButton.waitForExistence(timeout: 2))
        nameButton.tap()

        XCTAssertTrue(app.navigationBars["Profile & Settings"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testProtocolsCardNavigation() throws {
        let app = launchReadyApp()

        app.tabBars.buttons["Protocols"].tap()

        let gymCard = app.buttons["protocol.card.gym"]
        XCTAssertTrue(gymCard.waitForExistence(timeout: 2))
        gymCard.tap()

        XCTAssertTrue(app.staticTexts["CURRENT PLAN"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testLogsAccessFromHomeEntry() throws {
        let app = launchReadyApp()

        app.buttons["home.logsEntry"].tap()

        XCTAssertTrue(app.navigationBars["Logs"].waitForExistence(timeout: 2))
    }

    @MainActor
    func testLaunchPerformance() throws {
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            let app = XCUIApplication()
            app.launchArguments.append("--uitesting-ready")
            app.launch()
        }
    }

    @MainActor
    private func launchReadyApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("--uitesting-ready")
        app.launch()
        return app
    }
}
