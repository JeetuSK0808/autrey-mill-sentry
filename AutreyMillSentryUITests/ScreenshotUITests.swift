import XCTest

/// Walks the main screens and attaches a screenshot of each (kept in the .xcresult, exported by tools/screenshots.sh).
final class ScreenshotUITests: XCTestCase {
    private func shoot(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testWalkthroughScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-mockScan", "confirmed", "-simulateLocation", "-showLaunch"]
        app.launch()
        usleep(900_000); shoot(app, "00-launch")
        sleep(2)   // let the launch animation lift before interacting
        let next = app.buttons["onboarding.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        shoot(app, "01-onboarding")
        next.tap(); shoot(app, "02-onboarding-promise")
        next.tap(); shoot(app, "03-onboarding-permissions")
        next.tap()
        let sample = app.buttons["scan.samplePhoto"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        shoot(app, "04-scan")
        sample.tap()
        let save = app.buttons["result.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 20))
        shoot(app, "05-result-confirmed")
        save.tap()
        XCTAssertTrue(app.buttons["result.done"].waitForExistence(timeout: 10))
        shoot(app, "06-result-saved")
        app.buttons["result.done"].tap()
        app.tabBars.buttons["Map"].tap()
        sleep(2); shoot(app, "07-map")
        app.tabBars.buttons["Reports"].tap()
        sleep(1); shoot(app, "08-reports")
        app.tabBars.buttons["Learn"].tap()
        sleep(1); shoot(app, "09-learn")
        app.tabBars.buttons["Visit"].tap()
        sleep(1); shoot(app, "10-visit")
    }

    func testRangerScreenshots() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-skipOnboarding", "-mockScan", "confirmed", "-simulateLocation", "-rangerMode"]
        app.launch()
        let sample = app.buttons["scan.samplePhoto"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        sample.tap()
        let save = app.buttons["result.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 20))
        save.tap()
        XCTAssertTrue(app.buttons["result.done"].waitForExistence(timeout: 10))
        app.buttons["result.done"].tap()
        app.tabBars.buttons["Ranger"].tap()
        sleep(1); shoot(app, "11-ranger")
        let row = app.descendants(matching: .any)["ranger.row.0"].firstMatch
        var scrolls = 0
        while !row.exists && scrolls < 6 { app.swipeUp(); scrolls += 1 }
        row.tap()
        sleep(1); shoot(app, "12-ranger-report")
        let treated = app.buttons["ranger.status.treated"]
        var scrolls2 = 0
        while !treated.exists && scrolls2 < 6 { app.swipeUp(); scrolls2 += 1 }
        if treated.waitForExistence(timeout: 5) {
            addUIInterruptionMonitor(withDescription: "Notifications") { alert in
                if alert.buttons["Allow"].exists { alert.buttons["Allow"].tap(); return true }
                return false
            }
            treated.tap(); sleep(1)
            app.navigationBars.firstMatch.tap()   // lets the interruption monitor handle the system prompt
            sleep(1); shoot(app, "13-ranger-treated")
        }
        app.navigationBars.buttons.firstMatch.tap()
        app.tabBars.buttons["Reports"].tap()
        app.navigationBars.buttons["Settings"].tap()
        sleep(1); shoot(app, "14-settings")
        let about = app.staticTexts["About, accuracy and credits"]
        var tries = 0
        while !about.isHittable && tries < 6 { app.swipeUp(); tries += 1 }
        about.tap()
        sleep(1); shoot(app, "15-about-accuracy")
    }

    func testRescanScreenshot() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-skipOnboarding", "-mockScan", "ambiguous", "-simulateLocation"]
        app.launch()
        let sample = app.buttons["scan.samplePhoto"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        sample.tap()
        XCTAssertTrue(app.buttons["result.tryAgain"].waitForExistence(timeout: 20))
        shoot(app, "16-rescan-ambiguous")
    }
}
