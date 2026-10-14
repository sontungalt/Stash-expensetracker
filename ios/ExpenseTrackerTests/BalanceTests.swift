import Foundation
import Testing
@testable import ExpenseTracker

@Suite struct BalanceTests {
    let now = day(2026, 10, 13)
    let start = day(2026, 10, 12, hour: 0)
    let rows = [Entry(kind: .spent, amount: Decimal(string: "46.90")!, category: "Food", note: "Spending", date: day(2026, 10, 13))]

    @Test func correctingThreeTenToOneFiftyPreservesTheLedger() throws {
        let raw = try CurrentBalance.correction(target: Decimal(string: "1.50")!, entries: rows, allowance: 50, startsOn: start, now: now, calendar: utc)
        let totals = CurrentBalance.totals(rows, allowance: 50, startsOn: start, correction: raw, now: now, calendar: utc)
        #expect(totals.left == Decimal(string: "1.50")!)
        #expect(totals.moneyOut == Decimal(string: "46.90")!)
        #expect(totals.moneyIn == 50)
        #expect(Analytics.totals(rows).moneyOut == Decimal(string: "46.90")!)
        let updated = rows + [Entry(kind: .spent, amount: Decimal(string: "0.50")!, category: "Food", note: "Tea", date: now)]
        #expect(CurrentBalance.totals(updated, allowance: 50, startsOn: start, correction: raw, now: now, calendar: utc).left == 1)
    }

    @Test func correctionPersistsAndRepeatedEditsReplaceIt() throws {
        let defaults = UserDefaults(suiteName: "BalanceTests.\(UUID())")!
        defer { defaults.removeObject(forKey: CurrentBalance.storageKey) }
        let raw = try CurrentBalance.correction(target: Decimal(string: "1.50")!, entries: rows, allowance: 50, startsOn: start, now: now, calendar: utc)
        defaults.set(raw, forKey: CurrentBalance.storageKey)
        let saved = defaults.string(forKey: CurrentBalance.storageKey)!
        #expect(CurrentBalance.totals(rows, allowance: 50, startsOn: start, correction: saved, now: now, calendar: utc).left == Decimal(string: "1.50")!)
        let replacement = try CurrentBalance.correction(target: 2, entries: rows, allowance: 50, startsOn: start, now: now, calendar: utc)
        #expect(CurrentBalance.totals(rows, allowance: 50, startsOn: start, correction: replacement, now: now, calendar: utc).left == 2)
    }

    @Test func correctionExpiresExactlyAtMondayReset() throws {
        let raw = try CurrentBalance.correction(target: 0, entries: rows, allowance: 50, startsOn: start, now: now, calendar: utc)
        let monday = day(2026, 10, 19, hour: 0)
        #expect(CurrentBalance.totals(rows, allowance: 50, startsOn: start, correction: raw, now: monday.addingTimeInterval(-1), calendar: utc).left == 0)
        #expect(CurrentBalance.totals(rows, allowance: 50, startsOn: start, correction: raw, now: monday, calendar: utc).left == 50)
    }

    @Test func preActivationCorrectionEndsAtFirstReset() throws {
        let scheduled = day(2026, 10, 19, hour: 0)
        let raw = try CurrentBalance.correction(target: Decimal(string: "1.50")!, entries: rows, allowance: 50, startsOn: scheduled, now: now, calendar: utc)
        #expect(CurrentBalance.totals(rows, allowance: 50, startsOn: scheduled, correction: raw, now: now, calendar: utc).left == Decimal(string: "1.50")!)
        #expect(CurrentBalance.totals(rows, allowance: 50, startsOn: scheduled, correction: raw, now: scheduled, calendar: utc).left == 50)
    }

    @Test func balanceInputAllowsZeroButRejectsInvalidOrRoundedAmounts() {
        #expect(CurrentBalance.parseAmount("0.00") == 0)
        #expect(CurrentBalance.parseAmount(" 1,50 ") == Decimal(string: "1.50")!)
        for input in ["", "-1", "1.501", "NaN", "1,234.50", "1x"] {
            #expect(CurrentBalance.parseAmount(input) == nil)
        }
        #expect(CurrentBalance.totals(rows, allowance: 50, startsOn: start, correction: "invalid", now: now, calendar: utc).left == Decimal(string: "3.10")!)
    }
}
