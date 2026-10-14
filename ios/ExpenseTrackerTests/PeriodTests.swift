import Foundation
import Testing
@testable import ExpenseTracker

nonisolated let utc: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
nonisolated func day(_ y: Int, _ m: Int, _ d: Int, hour: Int = 12, calendar: Calendar = utc) -> Date {
    calendar.date(from: DateComponents(year: y, month: m, day: d, hour: hour))!
}

@Suite struct PeriodTests {
    @Test func monthKeyShiftsAcrossYears() {
        #expect(MonthKey(year: 2026, month: 1).shifted(-1) == MonthKey(year: 2025, month: 12))
        #expect(MonthKey(year: 2025, month: 12).shifted(1) == MonthKey(year: 2026, month: 1))
        #expect(MonthKey(year: 2026, month: 10).shortLabel == "Oct")
        #expect(MonthKey(year: 2026, month: 10).longLabel == "October 2026")
    }

    @Test func monthMembershipUsesCalendarDays() {
        var tokyo = Calendar(identifier: .gregorian); tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        // 23:30 on Oct 31 in Tokyo is still October there, even though it's Oct 31 14:30 UTC.
        let lateOct31 = day(2026, 10, 31, hour: 23, calendar: tokyo).addingTimeInterval(30 * 60)
        #expect(Period.month(MonthKey(year: 2026, month: 10)).contains(lateOct31, calendar: tokyo))
        #expect(!Period.month(MonthKey(year: 2026, month: 11)).contains(lateOct31, calendar: tokyo))
        #expect(Period.allTime.contains(lateOct31, calendar: tokyo))
    }

    @Test func weekResetsAtMondayMidnightEvenWithSundayFirstLocale() {
        var calendar = utc
        calendar.firstWeekday = 1
        let monday = day(2026, 10, 12, hour: 0)
        let sundayNight = monday.addingTimeInterval(-1)
        #expect(Period.week(containing: sundayNight, calendar: calendar).start == day(2026, 10, 5, hour: 0))
        #expect(Period.thisWeek.contains(sundayNight, calendar: calendar, now: sundayNight))
        #expect(!Period.thisWeek.contains(monday, calendar: calendar, now: sundayNight))
        #expect(Period.week(containing: monday, calendar: calendar).start == monday)
        #expect(!Period.thisWeek.contains(sundayNight, calendar: calendar, now: monday))
        #expect(Period.thisWeek.contains(monday, calendar: calendar, now: monday))
        #expect(Period.thisWeek.title == "This week")
        #expect(Period.validated(.thisWeek, in: [], calendar: calendar) == .thisWeek)
    }

    @Test func weekUsesLocalMidnightAcrossTimeZonesAndNewYear() {
        var tokyo = utc
        tokyo.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let monday = day(2026, 10, 12, hour: 0, calendar: tokyo)
        #expect(Period.week(containing: monday, calendar: tokyo).start == monday)
        #expect(!Period.thisWeek.contains(monday.addingTimeInterval(-1), calendar: tokyo, now: monday))
        let week = Period.week(containing: day(2027, 1, 3), calendar: utc)
        #expect(week.start == day(2026, 12, 28, hour: 0))
        #expect(week.end == day(2027, 1, 4, hour: 0))
    }

    @Test func weekFollowsCalendarDaysAcrossDaylightSavingChanges() {
        var calendar = utc
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let spring = Period.week(containing: day(2026, 3, 8, calendar: calendar), calendar: calendar)
        #expect(spring.start == day(2026, 3, 2, hour: 0, calendar: calendar))
        #expect(spring.end == day(2026, 3, 9, hour: 0, calendar: calendar))
        #expect(spring.duration == 167 * 3600)
        let autumn = Period.week(containing: day(2026, 11, 1, calendar: calendar), calendar: calendar)
        #expect(autumn.duration == 169 * 3600)
    }

    @Test func firstResetIsNextMondayAndIsNotPostponedByRelaunching() {
        let name = "AllowanceScheduleTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let start = AllowanceSchedule.startDate(in: defaults, now: day(2026, 10, 11), calendar: utc)
        #expect(start == day(2026, 10, 12, hour: 0))
        #expect(AllowanceSchedule.startDate(in: defaults, now: day(2026, 10, 12), calendar: utc) == start)
        #expect(AllowanceSchedule.startDate(in: defaults, now: day(2026, 10, 26), calendar: utc) == start)
    }

    @Test func monthsListIsNewestFirstAndDistinct() {
        let e = [Entry(kind: .spent, amount: 1, category: "Food", note: "a", date: day(2026, 8, 3)),
                 Entry(kind: .spent, amount: 1, category: "Food", note: "b", date: day(2026, 10, 1)),
                 Entry(kind: .received, amount: 1, category: "Gift", note: "c", date: day(2026, 8, 20))]
        #expect(Period.months(in: e, calendar: utc) == [MonthKey(year: 2026, month: 10), MonthKey(year: 2026, month: 8)])
        #expect(Period.allTime.title == "All time")
    }
}
