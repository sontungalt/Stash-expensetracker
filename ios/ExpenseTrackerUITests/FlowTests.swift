import XCTest

final class FlowTests: XCTestCase {
    @MainActor func testBalanceCanBeClearedAndReplacedWithoutDeletingDigits() {
        let app = launch()
        XCTAssertTrue(app.buttons["balance.edit"].waitForExistence(timeout: 10))
        app.buttons["balance.edit"].tap()
        let amount = app.textFields["balance.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        let clear = app.buttons["balance.clear"]
        XCTAssertTrue(clear.waitForExistence(timeout: 3))
        guard clear.exists else { return }
        clear.tap()
        XCTAssertEqual(amount.value as? String, "0.00") // Empty fields expose their placeholder.
        amount.typeText("1.50")
        app.buttons["balance.keyboardDone"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 3))
        let preview = XCTAttachment(screenshot: app.screenshot())
        preview.name = "Balance editor"
        preview.lifetime = .keepAlways
        add(preview)
        app.buttons["balance.save"].tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["hero.left"].label, "$1.50")
    }

    @MainActor func testTabsRemainUsableWithLargestAccessibilityText() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-allowanceActive", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        app.launch()
        let overview = app.buttons["tab.overview"]
        let activity = app.buttons["tab.activity"]
        XCTAssertTrue(overview.waitForExistence(timeout: 10))
        XCTAssertTrue(overview.isHittable)
        XCTAssertTrue(activity.isHittable)
        for (button, title) in [(overview, "Overview"), (activity, "Activity")] {
            let label = button.staticTexts[title]
            // SwiftUI merges a text-only label into the button. Icon + text
            // labels expose a child whose bounds can reveal layout overflow.
            guard label.exists else {
                XCTAssertEqual(button.label, title)
                continue
            }
            XCTAssertGreaterThanOrEqual(label.frame.minY, button.frame.minY, "\(title) must stay inside its tab")
            XCTAssertLessThanOrEqual(label.frame.maxY, button.frame.maxY, "\(title) must stay inside its tab")
            XCTAssertGreaterThanOrEqual(label.frame.minX, button.frame.minX)
            XCTAssertLessThanOrEqual(label.frame.maxX, button.frame.maxX)
        }
        let preview = XCTAttachment(screenshot: app.screenshot())
        preview.name = "Largest text Overview"
        preview.lifetime = .keepAlways
        add(preview)
        activity.tap()
        XCTAssertTrue(app.staticTexts["activity.left"].waitForExistence(timeout: 5))
        XCTAssertTrue(activity.isSelected)
        overview.tap()
        XCTAssertTrue(app.staticTexts["hero.left"].waitForExistence(timeout: 5))
        XCTAssertTrue(overview.isSelected)
        XCTAssertTrue(app.buttons["balance.edit"].isHittable)
    }

    @MainActor func testMoneyLeftCanBeEditedFromActivityAndSharedWithOverview() {
        let app = launch()
        XCTAssertTrue(app.buttons["tab.activity"].waitForExistence(timeout: 10))
        app.buttons["tab.activity"].tap()
        let edit = app.buttons["balance.edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5), "Activity must offer a balance correction even with no transactions")
        guard edit.exists else { return }
        edit.tap()
        let amount = app.textFields["balance.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "1.50")
        app.buttons["balance.save"].tap()
        XCTAssertTrue(app.buttons["balance.save"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["activity.left"].label, "$1.50")
        app.buttons["tab.overview"].tap()
        XCTAssertEqual(app.staticTexts["hero.left"].label, "$1.50")
        app.terminate()
        app.launchArguments.append("-keepAllowance")
        app.launch()
        XCTAssertTrue(app.staticTexts["hero.left"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["hero.left"].label, "$1.50")
        app.buttons["add"].firstMatch.tap()
        XCTAssertTrue(app.textFields["sheet.amount"].waitForExistence(timeout: 5))
        app.textFields["sheet.amount"].tap(); app.textFields["sheet.amount"].typeText("0.50")
        app.textFields["sheet.note"].tap(); app.textFields["sheet.note"].typeText("Tea after correction")
        app.buttons["sheet.save"].tap()
        XCTAssertTrue(app.buttons["sheet.save"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["hero.left"].label, "$1.00")
        app.buttons["tab.activity"].tap()
        XCTAssertEqual(app.staticTexts["activity.left"].label, "$1.00")
        app.segmentedControls["activity.kind"].buttons["In"].tap()
        XCTAssertEqual(app.staticTexts["activity.left"].label, "$1.00", "Transaction filters do not change money left")
    }

    @MainActor func testBalanceEditorSupportsCancelValidationAndZero() {
        let app = launch()
        let edit = app.buttons["balance.edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        edit.tap()
        let amount = app.textFields["balance.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap(); amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "1.50")
        app.buttons["balance.cancel"].tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["hero.left"].label, "$50.00")
        edit.tap()
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap(); amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "1.234")
        app.buttons["balance.save"].tap()
        XCTAssertTrue(app.staticTexts["balance.error"].waitForExistence(timeout: 5))
        amount.tap(); amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "0.00")
        app.buttons["balance.save"].tap()
        XCTAssertTrue(amount.waitForNonExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["hero.left"].label, "$0.00")
        app.buttons["tab.activity"].tap()
        XCTAssertEqual(app.staticTexts["activity.left"].label, "$0.00")
    }

    @MainActor private func launch(allowanceActive: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        if allowanceActive { app.launchArguments.append("-allowanceActive") }
        app.launch()
        return app
    }

    @MainActor func testFirstResetIsDeferredAndTodaysRecordedBalanceIsKept() {
        let app = launch(allowanceActive: false)
        let left = app.staticTexts["hero.left"]
        XCTAssertTrue(left.waitForExistence(timeout: 10))
        XCTAssertEqual(left.label, "$0.00", "the scheduled allowance must not be credited today")
        XCTAssertTrue(app.staticTexts["hero.firstReset"].exists)
        let resetLabel = app.staticTexts["hero.firstReset"].label
        app.buttons["add"].firstMatch.tap()
        XCTAssertTrue(app.segmentedControls["sheet.kind"].waitForExistence(timeout: 5))
        app.segmentedControls["sheet.kind"].buttons["Received"].tap()
        app.textFields["sheet.amount"].tap(); app.textFields["sheet.amount"].typeText("20")
        app.textFields["sheet.note"].tap(); app.textFields["sheet.note"].typeText("Existing allowance")
        app.buttons["sheet.save"].tap()
        XCTAssertTrue(app.buttons["sheet.save"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(left.label, "$20.00")
        app.buttons["add"].firstMatch.tap()
        XCTAssertTrue(app.textFields["sheet.amount"].waitForExistence(timeout: 5))
        app.textFields["sheet.amount"].tap(); app.textFields["sheet.amount"].typeText("4")
        app.textFields["sheet.note"].tap(); app.textFields["sheet.note"].typeText("Snack")
        app.buttons["sheet.save"].tap()
        XCTAssertTrue(app.buttons["sheet.save"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(left.label, "$16.00")
        XCTAssertEqual(app.staticTexts["hero.firstReset"].label, resetLabel)
        app.terminate()
        app.launchArguments.append("-keepAllowance")
        app.launch()
        XCTAssertTrue(app.staticTexts["hero.firstReset"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["hero.firstReset"].label, resetLabel)
    }

    @MainActor func testLiquidTabPillSupportsDraggingAndTapping() {
        let app = launch()
        let overview = app.buttons["tab.overview"]
        let activity = app.buttons["tab.activity"]
        XCTAssertTrue(overview.waitForExistence(timeout: 10))
        XCTAssertTrue(overview.isSelected)
        // A short drag from the edge must preserve the grab offset and settle back.
        let edge = overview.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5))
        edge.press(forDuration: 0.1, thenDragTo: edge.withOffset(CGVector(dx: 24, dy: 0)))
        XCTAssertTrue(overview.isSelected)
        let left = overview.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let right = activity.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        left.press(forDuration: 0.1, thenDragTo: right)
        XCTAssertTrue(app.staticTexts["activity.left"].waitForExistence(timeout: 5))
        XCTAssertTrue(activity.isSelected)
        right.press(forDuration: 0.1, thenDragTo: left)
        XCTAssertTrue(app.staticTexts["hero.left"].waitForExistence(timeout: 5))
        XCTAssertTrue(overview.isSelected)
        activity.tap()
        XCTAssertTrue(app.staticTexts["activity.left"].waitForExistence(timeout: 5))
        XCTAssertTrue(activity.isSelected)
    }

    @MainActor func testShellHasTwoTabsAndAnAddButton() {
        let app = launch()
        XCTAssertTrue(app.buttons["tab.overview"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["tab.activity"].exists)
        XCTAssertTrue(app.buttons["add"].exists)
    }

    @MainActor func testSampleDataShowsLeftAndExitReturnsToEmpty() {
        let app = launch()
        let sample = app.buttons["empty.sample"]
        XCTAssertTrue(sample.waitForExistence(timeout: 10))
        sample.tap()
        XCTAssertTrue(app.staticTexts["hero.left"].waitForExistence(timeout: 5))
        app.buttons["period.menu"].tap()
        let month = app.buttons["dropdown.item.2"]
        XCTAssertTrue(month.waitForExistence(timeout: 3))
        month.tap()
        XCTAssertTrue(app.staticTexts["hero.spent"].waitForExistence(timeout: 3))
        app.buttons["sample.exit"].firstMatch.tap()
        XCTAssertTrue(app.buttons["empty.sample"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["hero.left"].label, "$50.00", "empty history returns to a fresh weekly budget")
    }

    @MainActor func testActivityFiltersMoneyIn() {
        let app = launch()
        XCTAssertTrue(app.buttons["empty.sample"].waitForExistence(timeout: 10))
        app.buttons["empty.sample"].tap()
        app.buttons["tab.activity"].tap()
        let kind = app.segmentedControls["activity.kind"]
        XCTAssertTrue(kind.waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["activity.period"].label, "Past 7 days")
        kind.buttons["In"].tap()
        XCTAssertTrue(app.buttons["row.Weekly allowance"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["row.Rent"].exists)
    }

    @MainActor func testWeeklyAllowanceDeductsSpendingWithoutDoubleCountingIncome() {
        let app = launch()
        XCTAssertTrue(app.buttons["add"].firstMatch.waitForExistence(timeout: 10))

        app.buttons["add"].firstMatch.tap()
        let amount = app.textFields["sheet.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap(); amount.typeText("12.50")
        app.buttons["Food"].tap()
        let note = app.textFields["sheet.note"]
        note.tap(); note.typeText("Lunch")
        app.buttons["sheet.save"].tap()
        XCTAssertTrue(app.staticTexts["hero.left"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["hero.left"].label, "$37.50")

        app.buttons["add"].firstMatch.tap()
        XCTAssertTrue(app.segmentedControls["sheet.kind"].waitForExistence(timeout: 5))
        app.segmentedControls["sheet.kind"].buttons["Received"].tap()
        app.textFields["sheet.amount"].tap(); app.textFields["sheet.amount"].typeText("50")
        app.buttons["Allowance"].tap()
        app.textFields["sheet.note"].tap(); app.textFields["sheet.note"].typeText("Weekly allowance")
        app.textFields["sheet.from"].tap(); app.textFields["sheet.from"].typeText("Mum")
        app.buttons["sheet.save"].tap()
        let left = app.staticTexts["hero.left"]
        XCTAssertTrue(left.waitForExistence(timeout: 5))
        let updated = NSPredicate(format: "label == %@", "$37.50")
        expectation(for: updated, evaluatedWith: left)
        waitForExpectations(timeout: 5)

        app.buttons["tab.activity"].tap()
        XCTAssertTrue(app.buttons["row.Lunch"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["row.Weekly allowance"].exists)
    }

    @MainActor func testValidationKeepsTheSheetOpen() {
        let app = launch()
        XCTAssertTrue(app.buttons["add"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["add"].firstMatch.tap()
        XCTAssertTrue(app.buttons["sheet.save"].waitForExistence(timeout: 5))
        app.buttons["sheet.save"].tap()
        XCTAssertTrue(app.staticTexts["sheet.error"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["sheet.save"].exists)
    }

    @MainActor func testDoubleTapSavesOnce() {
        let app = launch()
        XCTAssertTrue(app.buttons["add"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["add"].firstMatch.tap()
        let amount = app.textFields["sheet.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap(); amount.typeText("4")
        app.textFields["sheet.note"].tap(); app.textFields["sheet.note"].typeText("Tea")
        app.buttons["sheet.save"].doubleTap()
        XCTAssertTrue(app.buttons["sheet.save"].waitForNonExistence(timeout: 5), "wait for the save confirmation sheet to dismiss before switching tabs")
        app.buttons["tab.activity"].tap()
        XCTAssertTrue(app.buttons["row.Tea"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons.matching(identifier: "row.Tea").count, 1)
    }

    @MainActor func testAmountFieldIsLabelledForVoiceOver() {
        let app = launch()
        XCTAssertTrue(app.buttons["add"].firstMatch.waitForExistence(timeout: 10))
        app.buttons["add"].firstMatch.tap()
        XCTAssertTrue(app.textFields["sheet.amount"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["sheet.amount"].label, "Amount")
    }

    @MainActor func testVerticalSwipeOverChartScrollsInsteadOfPickingAMonth() {
        let app = launch()
        XCTAssertTrue(app.buttons["empty.sample"].waitForExistence(timeout: 10))
        app.buttons["empty.sample"].tap()
        let chart = app.descendants(matching: .any)["overview.monthChart"].firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 5))
        // Bring the actual plot on screen; the section title has the same spoken label.
        app.scrollViews.firstMatch.swipeUp()
        XCTAssertTrue(chart.isHittable)
        let originalY = chart.frame.minY
        // Drag down so the gesture can scroll even if we are already at the bottom.
        let start = chart.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: 160)))
        XCTAssertGreaterThan(chart.frame.minY, originalY + 20, "a drag on the chart should scroll Overview")
        XCTAssertTrue(app.buttons["period.menu"].label.contains("This week"), "got \(app.buttons["period.menu"].label)")
    }

    @MainActor func testEditorDeleteCanBeUndoneFromTheTopBanner() {
        let app = launch()
        XCTAssertTrue(app.buttons["empty.sample"].waitForExistence(timeout: 10))
        app.buttons["empty.sample"].tap()
        app.buttons["tab.activity"].tap()
        app.segmentedControls["activity.kind"].buttons["In"].tap()
        let row = app.buttons["row.Weekly allowance"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let delete = app.buttons["sheet.delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        let undo = app.buttons["delete.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 2))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        XCTAssertFalse(row.exists)
        app.buttons["tab.overview"].tap()
        // The banner follows tab changes; its full visible capsule is tappable.
        undo.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85)).tap()
        app.buttons["tab.activity"].tap()
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        XCTAssertFalse(undo.exists)
    }

    @MainActor func testSwipeDeleteHasFiveSecondUndoAndThenExpires() {
        let app = launch()
        XCTAssertTrue(app.buttons["empty.sample"].waitForExistence(timeout: 10))
        app.buttons["empty.sample"].tap()
        app.buttons["tab.activity"].tap()
        app.segmentedControls["activity.kind"].buttons["In"].tap()
        let row = app.buttons["row.Weekly allowance"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.swipeLeft()
        let action = app.buttons["Delete transaction"]
        XCTAssertTrue(action.waitForExistence(timeout: 2))
        let swipePreview = XCTAttachment(screenshot: app.screenshot())
        swipePreview.name = "Red swipe Delete"
        swipePreview.lifetime = .keepAlways
        add(swipePreview)
        action.tap()
        let undo = app.buttons["delete.undo"]
        XCTAssertTrue(undo.waitForExistence(timeout: 2))
        XCTAssertFalse(row.exists)
        let undoPreview = XCTAttachment(screenshot: app.screenshot())
        undoPreview.name = "Five-second Undo banner"
        undoPreview.lifetime = .keepAlways
        add(undoPreview)
        undo.tap()
        XCTAssertTrue(row.waitForExistence(timeout: 3))
        let start = row.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: row.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.5)))
        XCTAssertTrue(undo.waitForExistence(timeout: 2))
        XCTAssertTrue(undo.waitForNonExistence(timeout: 7))
        XCTAssertFalse(row.exists)
        XCTAssertFalse(app.alerts.firstMatch.exists)
    }

    @MainActor func testPeriodDropdownPicksAMonth() {
        let app = launch()
        XCTAssertTrue(app.buttons["empty.sample"].waitForExistence(timeout: 10))
        app.buttons["empty.sample"].tap()
        let trigger = app.buttons["period.menu"]
        XCTAssertTrue(trigger.waitForExistence(timeout: 5))
        trigger.tap()
        let item = app.buttons["dropdown.item.2"]
        XCTAssertTrue(item.waitForExistence(timeout: 3), "first month in the menu")
        let month = item.label
        item.tap()
        XCTAssertTrue(trigger.label.contains(month), "trigger shows \(month), got \(trigger.label)")
        XCTAssertFalse(app.buttons["dropdown.item.2"].exists, "menu closes after picking")
        XCTAssertTrue(app.staticTexts["hero.spent"].exists, "a month shows historical spending, not a carried-over weekly balance")
        trigger.tap()
        app.buttons["dropdown.item.0"].tap()
        XCTAssertTrue(app.staticTexts["hero.left"].exists)
        XCTAssertTrue(trigger.label.contains("This week"))
    }

    @MainActor func testWeeklyAllowanceIsEditableAndPersistsWithoutAnyTransactions() {
        let app = launch()
        let left = app.staticTexts["hero.left"]
        XCTAssertTrue(left.waitForExistence(timeout: 10))
        XCTAssertEqual(left.label, "$50.00")
        app.buttons["allowance.edit"].tap()
        let amount = app.textFields["allowance.amount"]
        XCTAssertTrue(amount.waitForExistence(timeout: 5))
        amount.tap()
        amount.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 2) + "0")
        app.buttons["allowance.save"].tap()
        XCTAssertTrue(app.staticTexts["allowance.error"].waitForExistence(timeout: 3))
        amount.tap()
        amount.typeText(XCUIKeyboardKey.delete.rawValue + "75")
        app.buttons["allowance.save"].tap()
        XCTAssertTrue(app.buttons["allowance.save"].waitForNonExistence(timeout: 5))
        XCTAssertEqual(left.label, "$75.00")
        app.terminate()
        app.launchArguments.append("-keepAllowance")
        app.launch()
        XCTAssertTrue(left.waitForExistence(timeout: 10))
        XCTAssertEqual(left.label, "$75.00")
    }

    @MainActor func testGroupByDayLiquidToggle() {
        let app = launch()
        XCTAssertTrue(app.buttons["empty.sample"].waitForExistence(timeout: 10))
        app.buttons["empty.sample"].tap()
        app.buttons["tab.activity"].tap()
        let toggle = app.switches["Group by day"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "1")
        toggle.tap()
        XCTAssertTrue(app.staticTexts["ALL ACTIVITY"].waitForExistence(timeout: 3), "ungrouped list has one section")
    }
}
