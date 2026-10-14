import XCTest

final class StashFlowTests: XCTestCase {
    @MainActor func testIslandLinksOpenFromBalanceAndAllowanceEditors() {
        let app = launch()
        XCTAssertTrue(app.buttons["balance.edit"].waitForExistence(timeout: 10))
        app.buttons["balance.edit"].tap()
        XCTAssertTrue(app.textFields["balance.amount"].waitForExistence(timeout: 5))
        app.open(URL(string: "expensetracker://stash")!)
        XCTAssertTrue(app.buttons["stash.island"].waitForExistence(timeout: 5))
        guard app.buttons["stash.island"].exists else { return }
        app.buttons["Done"].tap()
        app.buttons["allowance.edit"].tap()
        XCTAssertTrue(app.textFields["allowance.amount"].waitForExistence(timeout: 5))
        app.open(URL(string: "expensetracker://add")!)
        XCTAssertTrue(app.textFields["sheet.amount"].waitForExistence(timeout: 5))
    }

    @MainActor func testStashFollowsCorrectedBalanceAndCanPreviewWithoutChangingMoney() {
        let app = launch()
        XCTAssertTrue(app.buttons["stash.open"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["stash.open"].label, "Meet Stash, Stuffed")
        app.buttons["balance.edit"].tap()
        XCTAssertTrue(app.buttons["balance.clear"].waitForExistence(timeout: 5))
        app.buttons["balance.clear"].tap()
        app.textFields["balance.amount"].typeText("1.50")
        app.buttons["balance.save"].tap()
        XCTAssertTrue(app.buttons["balance.save"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["hero.left"].label, "$1.50")
        XCTAssertEqual(app.buttons["stash.open"].label, "Meet Stash, Running low")
        capture(app, "Stash beside corrected balance")
        app.buttons["stash.open"].tap()
        XCTAssertTrue(app.staticTexts["stash.balance"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["stash.balance"].label, "Money left: $1.50")
        capture(app, "Stash companion")
        app.buttons["stash.preview"].tap()
        let goal = app.buttons["Goal reached"]
        XCTAssertTrue(goal.waitForExistence(timeout: 5))
        goal.tap()
        XCTAssertEqual(app.staticTexts["stash.status"].label, "Goal reached")
        XCTAssertEqual(app.staticTexts["stash.balance"].label, "Money left: $1.50")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.buttons["stash.open"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["hero.left"].label, "$1.50")
        app.buttons["add"].firstMatch.tap()
        XCTAssertTrue(app.textFields["sheet.amount"].waitForExistence(timeout: 5))
        app.textFields["sheet.amount"].tap(); app.textFields["sheet.amount"].typeText("2")
        app.textFields["sheet.note"].tap(); app.textFields["sheet.note"].typeText("Tea with Stash")
        app.buttons["sheet.save"].tap()
        XCTAssertTrue(app.buttons["sheet.save"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["hero.left"].label, "Over by $0.50")
        app.buttons["stash.open"].tap()
        XCTAssertTrue(app.staticTexts["stash.balance"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["stash.balance"].label, "Over by: $0.50")
    }

    @MainActor func testLiveActivityStartsUpdatesAndStops() {
        let app = launch()
        XCTAssertTrue(app.buttons["stash.open"].waitForExistence(timeout: 10))
        app.buttons["stash.open"].tap()
        let control = app.buttons["stash.island"]
        XCTAssertTrue(control.waitForExistence(timeout: 5))
        if control.label == "Hide from Dynamic Island" {
            control.tap()
            XCTAssertTrue(control.wait(for: \.label, toEqual: "Show in Dynamic Island", timeout: 5))
        }
        control.tap()
        XCTAssertTrue(control.wait(for: \.label, toEqual: "Hide from Dynamic Island", timeout: 10), app.staticTexts["stash.error"].exists ? app.staticTexts["stash.error"].label : "Live Activity did not start")
        XCUIDevice.shared.press(.home)
        // Let the Home transition finish before inspecting the system-rendered Island.
        Thread.sleep(forTimeInterval: 2)
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCTAssertTrue(springboard.staticTexts["Money left, $50.00"].waitForExistence(timeout: 5))
        capture(springboard, "Stash Dynamic Island")
        app.activate()
        XCTAssertTrue(control.waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["balance.edit"].tap()
        XCTAssertTrue(app.buttons["balance.clear"].waitForExistence(timeout: 5))
        app.buttons["balance.clear"].tap(); app.textFields["balance.amount"].typeText("1.50")
        app.buttons["balance.save"].tap()
        XCTAssertTrue(app.buttons["balance.save"].waitForNonExistence(timeout: 5))
        XCUIDevice.shared.press(.home)
        Thread.sleep(forTimeInterval: 2)
        XCTAssertTrue(springboard.staticTexts["Money left, $1.50"].waitForExistence(timeout: 5))
        capture(springboard, "Stash Island corrected balance")
        springboard.otherElements["regular.view"].press(forDuration: 1)
        XCTAssertTrue(springboard.staticTexts["Stash is looking after your balance"].waitForExistence(timeout: 5))
        capture(springboard, "Stash expanded Island")
        let addExpense = springboard.buttons["Add expense"]
        XCTAssertTrue(addExpense.waitForExistence(timeout: 5))
        addExpense.tap()
        XCTAssertTrue(app.textFields["sheet.amount"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        if !control.waitForExistence(timeout: 2) { app.buttons["stash.open"].tap() }
        XCTAssertTrue(control.waitForExistence(timeout: 5))
        XCTAssertEqual(control.label, "Hide from Dynamic Island")
        control.tap()
        XCTAssertTrue(control.wait(for: \.label, toEqual: "Show in Dynamic Island", timeout: 5))
    }

    @MainActor private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-allowanceActive"]
        app.launch()
        return app
    }

    @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
