import Foundation
import SwiftData
import Testing
@testable import ExpenseTracker

@Suite struct ReviewFixTests {
    @Test func calendarDayAnchorsToNoon() {
        let lateNight = day(2026, 10, 31, hour: 23).addingTimeInterval(50 * 60)
        #expect(Entry.calendarDay(lateNight, calendar: utc) == day(2026, 10, 31, hour: 12))
    }

    @Test func amountParserIsStrict() {
        #expect(AmountParser.parse("12.50") == Decimal(string: "12.5"))
        #expect(AmountParser.parse("12,50") == Decimal(string: "12.5"))
        #expect(AmountParser.parse(" 7 ") == 7)
        #expect(AmountParser.parse("1,234.50") == Decimal(string: "1234.5"))
        #expect(AmountParser.parse("12abc") == nil)
        #expect(AmountParser.parse("1e3") == nil)
        #expect(AmountParser.parse("1.2.3") == nil)
        #expect(AmountParser.parse("0") == nil)
        #expect(AmountParser.parse("") == nil)
        #expect(AmountParser.parse("12.345") == Decimal(string: "12.35"), "rounds to cents")
    }

    @Test func heroTextOnBurntOrangeMeetsAA() {
        for (name, fg, bg) in [("label", Palette.heroText, Palette.sunny.accent), ("pill", Palette.heroText, Palette.heroPill)] {
            #expect(Palette.contrast(fg, bg) >= 4.5, "\(name)")
        }
    }

    @Test func moneyInRecentsAreDistinctBySender() {
        let rows = [
            Entry(kind: .received, amount: 50, category: "Allowance", note: "Weekly allowance", from: "Mum", date: day(2026, 10, 6)),
            Entry(kind: .received, amount: 40, category: "Allowance", note: "Weekly allowance", from: "Dad", date: day(2026, 10, 5)),
            Entry(kind: .received, amount: 50, category: "Allowance", note: "weekly allowance", from: "mum", date: day(2026, 9, 29)),
        ]
        #expect(ActivityQuery.recents(rows, kind: .received).map { $0.from } == ["Mum", "Dad"])
    }

    @Test func stalePeriodFallsBackToAllTime() {
        let rows = [Entry(kind: .spent, amount: 1, category: "Food", note: "a", date: day(2026, 10, 1))]
        #expect(Period.validated(.month(MonthKey(year: 2026, month: 5)), in: rows, calendar: utc) == .allTime)
        #expect(Period.validated(.month(MonthKey(year: 2026, month: 10)), in: rows, calendar: utc) == .month(MonthKey(year: 2026, month: 10)))
        #expect(Period.validated(.allTime, in: [], calendar: utc) == .allTime)
    }

    @Test func barsEndAtTheLatestMonthWithData() {
        let march = [Entry(kind: .spent, amount: 1, category: "Food", note: "a", date: day(2026, 3, 1))]
        #expect(Analytics.latestMonth(march, now: day(2026, 10, 10), calendar: utc) == MonthKey(year: 2026, month: 3))
    }

    @Test func spendingChipUnderAllDoesNotMatchMoneyIn() {
        let rows = [Entry(kind: .spent, amount: 1, category: "Other", note: "spent other", date: day(2026, 10, 1)),
                    Entry(kind: .received, amount: 2, category: "Other", note: "received other", date: day(2026, 10, 1))]
        #expect(ActivityQuery.apply(.init(category: "Other"), to: rows).map { $0.note } == ["spent other"])
    }
}

@MainActor @Suite struct StoreReviewFixTests {
    @Test func storedDatesAreCalendarDaysAtNoon() throws {
        let store = TransactionStore(context: ModelContext(try TransactionStore.makeContainer(inMemory: true)))
        let local = Calendar.current
        let late = local.date(bySettingHour: 23, minute: 50, second: 0, of: .now)!
        try store.add(Entry(kind: .spent, amount: 3, category: "Food", note: "Late snack", date: late))
        #expect(local.component(.hour, from: try store.all()[0].date) == 12)
    }
}
