import XCTest

/// Happy path with the mock classifier and the bundled sample photo: scan, result, save, see it in Reports.
final class HappyPathUITests: XCTestCase {
    func testScanSaveAndListReport() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-skipOnboarding", "-mockScan", "confirmed", "-simulateLocation"]
        app.launch()
        let sample = app.buttons["scan.samplePhoto"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        sample.tap()
        let save = app.buttons["result.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Chinese privet"].exists)
        save.tap()
        let done = app.buttons["result.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        done.tap()
        app.tabBars.buttons["Reports"].tap()
        XCTAssertTrue(app.staticTexts["Chinese privet"].waitForExistence(timeout: 5))
    }

    func testRescanShowsSpecificInstruction() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-skipOnboarding", "-mockScan", "notplant", "-simulateLocation"]
        app.launch()
        let sample = app.buttons["scan.samplePhoto"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        sample.tap()
        XCTAssertTrue(app.buttons["result.tryAgain"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["No plant in view"].exists)
    }
}
