import Foundation
import Testing
@testable import ExpenseTracker

private func out(_ amount: String, _ category: String, _ date: Date, note: String = "x") -> Entry {
    Entry(kind: .spent, amount: Decimal(string: amount)!, category: category, note: note, date: date)
}
private func inn(_ amount: String, _ category: String, _ date: Date, from: String? = "Mum") -> Entry {
    Entry(kind: .received, amount: Decimal(string: amount)!, category: category, note: "in", from: from, date: date)
}

@Suite struct AnalyticsTests {
    @Test func totalsAreExactToTheCent() {
        let t = Analytics.totals([out("0.1", "Food", day(2026, 10, 1)), out("0.2", "Food", day(2026, 10, 1)),
                                  inn("1000000.01", "Job", day(2026, 10, 2))])
        #expect(t.moneyOut == Decimal(string: "0.3")!)
        #expect(t.moneyIn == Decimal(string: "1000000.01")!)
        #expect(t.left == Decimal(string: "999999.71")!)
    }

    @Test func overspendIsReportedAsOver() {
        let t = Analytics.totals([inn("50", "Allowance", day(2026, 10, 5)), out("80", "Food", day(2026, 10, 6))])
        #expect(t.isOver)
        #expect(t.left == -30)
        #expect(!Analytics.totals([]).isOver)
    }

    @Test func filterByPeriod() {
        let e = [out("1", "Food", day(2026, 9, 30)), out("2", "Food", day(2026, 10, 1))]
        #expect(Analytics.filter(e, period: .month(MonthKey(year: 2026, month: 10)), calendar: utc).map(\.amount) == [2])
        #expect(Analytics.filter(e, period: .allTime, calendar: utc).count == 2)
    }

    @Test func weeklyAllowanceResetsWithoutRolloverOrDuplicateIncome() {
        let monday = day(2026, 10, 12, hour: 0)
        let entries = [out("80", "Food", day(2026, 10, 11)),
                       inn("50", "Allowance", day(2026, 10, 12)),
                       out("12.50", "Food", day(2026, 10, 12))]
        let current = Analytics.weeklyAllowance(entries, amount: 50, now: monday, calendar: utc)
        #expect(current == Totals(moneyIn: 50, moneyOut: Decimal(string: "12.50")!))
        #expect(current.left == Decimal(string: "37.50")!)
        let nextMonday = day(2026, 10, 19, hour: 0)
        #expect(Analytics.weeklyAllowance(entries, amount: 50, now: nextMonday, calendar: utc).left == 50)
        #expect(Analytics.weeklyAllowance(entries, amount: 75, now: monday, calendar: utc).left == Decimal(string: "62.50")!)
        #expect(Analytics.weeklyAllowance([], amount: 50, now: monday, calendar: utc).left == 50)
        #expect(entries.count == 3, "a reset never deletes or synthesizes transactions")
    }

    @Test func balanceIsPreservedUntilTheScheduledMondayNotResetImmediately() {
        let start = day(2026, 10, 12, hour: 0)
        let rows = [inn("75", "Allowance", day(2026, 10, 1)), out("12.50", "Food", day(2026, 10, 11))]
        let before = Analytics.weeklyAllowance(rows, amount: 50, startsOn: start, now: start.addingTimeInterval(-1), calendar: utc)
        #expect(before == Analytics.totals(rows))
        #expect(before.left == Decimal(string: "62.50")!)
        #expect(Analytics.weeklyAllowance(rows, amount: 100, startsOn: start, now: start.addingTimeInterval(-1), calendar: utc) == before,
                "changing the future allowance must not change today's balance")
        #expect(Analytics.weeklyAllowance(rows, amount: 50, startsOn: start, now: start, calendar: utc).left == 50)
        let withNewSpending = rows + [out("4.50", "Food", day(2026, 10, 12))]
        #expect(Analytics.weeklyAllowance(withNewSpending, amount: 50, startsOn: start, now: day(2026, 10, 12), calendar: utc).left == Decimal(string: "45.50")!)
        #expect(Analytics.weeklyAllowance(withNewSpending, amount: 50, startsOn: start, now: day(2026, 10, 19), calendar: utc).left == 50)
        #expect(Analytics.totals(rows).moneyOut == Decimal(string: "12.50")!, "history is never reset")
    }

    @Test func weeklyResetPreservesMonthlySpendingAcrossMonthBoundaries() {
        let entries = [out("10", "Food", day(2026, 9, 30)), out("15", "Transport", day(2026, 10, 1))]
        let week = Analytics.weeklyAllowance(entries, amount: 50, now: day(2026, 10, 1), calendar: utc)
        #expect(week.left == 25)
        let october = Analytics.filter(entries, period: .month(MonthKey(year: 2026, month: 10)), calendar: utc)
        #expect(Analytics.totals(october).moneyOut == 15)
        #expect(Analytics.monthlySpending(entries, endingAt: MonthKey(year: 2026, month: 10), count: 2, calendar: utc).map(\.total) == [10, 15])
        #expect(Analytics.weeklyAllowance(entries, amount: 50, now: day(2026, 10, 5), calendar: utc).left == 50)
    }

    @Test func monthlySpendingIgnoresMoneyInAndFillsGaps() {
        let e = [out("10", "Food", day(2026, 10, 2)), out("5", "Bills", day(2026, 8, 2)), inn("99", "Gift", day(2026, 10, 3))]
        let bars = Analytics.monthlySpending(e, endingAt: MonthKey(year: 2026, month: 10), count: 3, calendar: utc)
        #expect(bars.map(\.key.month) == [8, 9, 10])
        #expect(bars.map(\.total) == [5, 0, 10])
    }

    @Test func latestMonthIsTheNewestDataMonthOrNow() {
        let now = day(2026, 10, 10)
        #expect(Analytics.latestMonth([out("1", "Food", day(2026, 12, 1))], now: now, calendar: utc) == MonthKey(year: 2026, month: 12))
        #expect(Analytics.latestMonth([], now: now, calendar: utc) == MonthKey(year: 2026, month: 10))
    }

    @Test func categoryTotalsAreSpendingOnlyBiggestFirst() {
        let e = [out("30", "Food", day(2026, 10, 1)), out("10", "Food", day(2026, 10, 2)),
                 out("40", "Transport", day(2026, 10, 3)), inn("500", "Job", day(2026, 10, 3))]
        #expect(Analytics.categoryTotals(e) == [CategoryTotal(name: "Food", value: 40), CategoryTotal(name: "Transport", value: 40)])
        let top = Analytics.topShare(e)!
        #expect(top.name == "Food" && top.share == 50)
        #expect(Analytics.topShare([inn("5", "Gift", day(2026, 10, 1))]) == nil)
    }

    @Test func focusCopyAndQuip() {
        #expect(Analytics.focusCopy(name: "Bills", share: 80) == "Bills is 80% of this period’s spend.")
        #expect(Analytics.quip([out("900", "Bills", day(2026, 10, 1)), out("50", "Food", day(2026, 10, 1))]) == "Mostly 💡 Bills, peak adulting")
        #expect(Analytics.quip([inn("5", "Gift", day(2026, 10, 1))]) == "")
    }

    @Test func mixSharesSumToOne() {
        let m = Analytics.mix([out("60", "Bills", day(2026, 10, 1)), out("40", "Food", day(2026, 10, 1))])
        #expect(m.map(\.name) == ["Bills", "Food"])
        #expect(m.map(\.share) == [0.6, 0.4])
        #expect(Analytics.mix([]).isEmpty)
    }

    @Test func spendingDeltaVersusPreviousMonth() {
        let e = [out("100", "Food", day(2026, 9, 5)), out("120", "Food", day(2026, 10, 5))]
        #expect(Analytics.spendingDelta(e, month: MonthKey(year: 2026, month: 10), calendar: utc) == 20)
        #expect(Analytics.spendingDelta(e, month: MonthKey(year: 2026, month: 9), calendar: utc) == nil)
    }
}
