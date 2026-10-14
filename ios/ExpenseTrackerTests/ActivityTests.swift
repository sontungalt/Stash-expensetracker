import Foundation
import Testing
@testable import ExpenseTracker

private func e(_ kind: Kind, _ amount: Decimal, _ category: String, _ note: String, _ date: Date, from: String? = nil) -> Entry {
    Entry(kind: kind, amount: amount, category: category, note: note, from: from, date: date)
}

@Suite struct ActivityTests {
    @Test func lastSevenDaysIncludesTodayAndSixPreviousDaysOnly() {
        let now = day(2026, 10, 13, hour: 0)
        let history = [
            e(.spent, 1, "Food", "Too old", day(2026, 10, 6, hour: 23)),
            e(.spent, 2, "Food", "First day", day(2026, 10, 7, hour: 0)),
            e(.received, 50, "Allowance", "Today", day(2026, 10, 13, hour: 12)),
            e(.spent, 3, "Food", "Future", day(2026, 10, 14, hour: 0)),
        ]
        let recent = ActivityQuery.lastSevenDays(history, now: now, calendar: utc)
        #expect(recent.map(\.note) == ["First day", "Today"])
        #expect(history.count == 4, "Filtering never deletes the saved history")
        #expect(ActivityQuery.groups(recent, filter: .init(), now: now, calendar: utc).flatMap(\.entries).count == 2)
        #expect(Analytics.totals(recent).moneyOut == 2)
        #expect(Analytics.totals(recent).moneyIn == 50)
    }

    @Test func sevenDayWindowMovesForwardAtLocalMidnight() {
        var singapore = Calendar(identifier: .gregorian)
        singapore.timeZone = TimeZone(identifier: "Asia/Singapore")!
        let first = singapore.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 12))!
        let before = singapore.date(from: DateComponents(year: 2026, month: 10, day: 13, hour: 23, minute: 59))!
        let after = singapore.date(from: DateComponents(year: 2026, month: 10, day: 14, hour: 0))!
        let entries = [e(.spent, 2, "Food", "Boundary", first)]
        #expect(ActivityQuery.lastSevenDays(entries, now: before, calendar: singapore).count == 1)
        #expect(ActivityQuery.lastSevenDays(entries, now: after, calendar: singapore).isEmpty)
    }

    @Test func sevenDayWindowUsesCalendarDaysAcrossDaylightSaving() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        let now = calendar.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 14))!
        let start = calendar.date(from: DateComponents(year: 2026, month: 3, day: 3, hour: 0))!
        let entries = [e(.spent, 1, "Food", "Before", start.addingTimeInterval(-1)),
                       e(.spent, 2, "Food", "Start", start)]
        #expect(ActivityQuery.lastSevenDays(entries, now: now, calendar: calendar).map(\.note) == ["Start"])
    }

    let rows = [
        e(.spent, 12, "Food", "Lunch", day(2026, 10, 10, hour: 13)),
        e(.received, 50, "Allowance", "Weekly allowance", day(2026, 10, 10, hour: 9), from: "Mum"),
        e(.spent, 80, "Bills", "Electricity", day(2026, 10, 9)),
        e(.spent, 3, "Food", "Coffee", day(2026, 9, 1)),
    ]

    @Test func kindCategoryAndSearchFilters() {
        #expect(ActivityQuery.apply(.init(kind: .received), to: rows).map(\.note) == ["Weekly allowance"])
        #expect(ActivityQuery.apply(.init(kind: .spent, category: "Food"), to: rows).map(\.note) == ["Lunch", "Coffee"])
        #expect(ActivityQuery.apply(.init(search: "mum"), to: rows).map(\.note) == ["Weekly allowance"], "search matches the sender too")
        #expect(ActivityQuery.apply(.init(search: "  ELEC "), to: rows).map(\.note) == ["Electricity"])
    }

    @Test func sortOrders() {
        #expect(ActivityQuery.apply(.init(sort: .highest), to: rows).map(\.amount) == [80, 50, 12, 3])
        #expect(ActivityQuery.apply(.init(sort: .lowest), to: rows).map(\.amount) == [3, 12, 50, 80])
        #expect(ActivityQuery.apply(.init(sort: .oldest), to: rows).first?.note == "Coffee")
        #expect(ActivityQuery.apply(.init(sort: .newest), to: rows).first?.note == "Lunch")
    }

    @Test func dayGroupsSumSpendingOnly() {
        let groups = ActivityQuery.groups(rows, filter: .init(), now: day(2026, 10, 10, hour: 18), calendar: utc)
        #expect(groups.map(\.title) == ["Today", "Yesterday", "Tue, Sep 1"])
        #expect(groups[0].spent == 12, "money in doesn't count toward a day's spend")
        #expect(groups[0].entries.count == 2)
    }

    @Test func ungroupedIsOneSection() {
        let groups = ActivityQuery.groups(rows, filter: .init(sort: .highest), now: day(2026, 10, 10), calendar: utc)
        #expect(groups.count == 1)
        #expect(groups[0].title == "Highest amount")
    }

    @Test func dayTitles() {
        let now = day(2026, 10, 10, hour: 0)
        #expect(ActivityQuery.dayTitle(day(2026, 10, 10, hour: 23), now: now, calendar: utc) == "Today")
        #expect(ActivityQuery.dayTitle(day(2026, 10, 9, hour: 23), now: now, calendar: utc) == "Yesterday")
        #expect(ActivityQuery.dayTitle(day(2025, 12, 25), now: now, calendar: utc) == "Thu, Dec 25 2025")
    }

    @Test func recentsAreDistinctNewestFirstPerKind() {
        let more = rows + [e(.spent, 13, "Food", " lunch ", day(2026, 10, 8))]
        #expect(ActivityQuery.recents(more, kind: .spent).map(\.note) == ["Lunch", "Electricity", "Coffee"])
        #expect(ActivityQuery.recents(more, kind: .received).map(\.from) == ["Mum"])
    }
}
