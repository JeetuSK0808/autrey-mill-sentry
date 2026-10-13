import XCTest

/// Runs Xcode's built-in accessibility audit (contrast, hit size, Dynamic Type, element descriptions, traits)
/// on the main screens. Any failure is a real finding; results are recorded in docs/DESIGN_CHECKLIST.md.
final class AccessibilityAuditUITests: XCTestCase {
    private func audit(_ app: XCUIApplication, _ screen: String) throws {
        sleep(2)   // let appear animations finish so the audit measures the settled layout
        try app.performAccessibilityAudit(for: .all) { issue in
            // Report everything except the known-noisy "sufficient element description" for decorative images we already hide.
            let text = "\(screen): [\(issue.auditType)] \(issue.compactDescription) on \(issue.element?.description ?? "?") :: \(issue.detailedDescription)"
            let attachment = XCTAttachment(string: text)
            attachment.name = "a11y-\(screen)"
            attachment.lifetime = .keepAlways
            self.add(attachment)
            return false   // false = report the issue (do not ignore)
        }
    }

    func testAuditMainScreens() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-mockScan", "confirmed", "-simulateLocation"]
        app.launch()
        XCTAssertTrue(app.buttons["onboarding.next"].waitForExistence(timeout: 10))
        try audit(app, "onboarding")
        app.buttons["onboarding.next"].tap(); app.buttons["onboarding.next"].tap(); app.buttons["onboarding.next"].tap()
        XCTAssertTrue(app.buttons["scan.samplePhoto"].waitForExistence(timeout: 10))
        try audit(app, "scan")
        app.buttons["scan.samplePhoto"].tap()
        XCTAssertTrue(app.buttons["result.save"].waitForExistence(timeout: 20))
        try audit(app, "result")
        app.buttons["result.save"].tap()
        XCTAssertTrue(app.buttons["result.done"].waitForExistence(timeout: 10))
        app.buttons["result.done"].tap()
        app.tabBars.buttons["Map"].tap(); sleep(2)
        try audit(app, "map")
        app.tabBars.buttons["Reports"].tap(); sleep(1)
        try audit(app, "reports")
        app.tabBars.buttons["Learn"].tap(); sleep(1)
        try audit(app, "learn")
        app.tabBars.buttons["Visit"].tap(); sleep(1)
        try audit(app, "visit")
    }

    func testAuditRangerAndSettings() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-skipOnboarding", "-mockScan", "confirmed", "-simulateLocation", "-rangerMode"]
        app.launch()
        XCTAssertTrue(app.buttons["scan.samplePhoto"].waitForExistence(timeout: 10))
        app.buttons["scan.samplePhoto"].tap()
        XCTAssertTrue(app.buttons["result.save"].waitForExistence(timeout: 20))
        app.buttons["result.save"].tap()
        XCTAssertTrue(app.buttons["result.done"].waitForExistence(timeout: 10))
        app.buttons["result.done"].tap()
        app.tabBars.buttons["Ranger"].tap(); sleep(1)
        try audit(app, "ranger")
        app.tabBars.buttons["Reports"].tap()
        app.navigationBars.buttons["Settings"].tap(); sleep(1)
        try audit(app, "settings")
    }
}
