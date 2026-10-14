import Foundation

nonisolated struct MonthKey: Hashable, Comparable, Sendable {
    let year: Int
    let month: Int

    init(year: Int, month: Int) { self.year = year; self.month = month }
    init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month], from: date)
        self.init(year: c.year!, month: c.month!)
    }

    static func < (a: MonthKey, b: MonthKey) -> Bool { (a.year, a.month) < (b.year, b.month) }

    func shifted(_ months: Int) -> MonthKey {
        let index = year * 12 + (month - 1) + months
        return MonthKey(year: index / 12, month: index % 12 + 1)
    }

    private static let short = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private static let long = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
    var shortLabel: String { Self.short[month - 1] }
    var longLabel: String { "\(Self.long[month - 1]) \(year)" }
}

nonisolated enum Period: Hashable, Sendable {
    case thisWeek
    case allTime
    case month(MonthKey)

    /// Monday at local midnight through (but not including) the following Monday.
    static func week(containing now: Date, calendar: Calendar = .current) -> DateInterval {
        let today = calendar.startOfDay(for: now)
        let daysSinceMonday = (calendar.component(.weekday, from: today) + 5) % 7
        let start = calendar.date(byAdding: .day, value: -daysSinceMonday, to: today)!
        let end = calendar.date(byAdding: .day, value: 7, to: start)!
        return DateInterval(start: start, end: end)
    }

    func contains(_ date: Date, calendar: Calendar = .current, now: Date = .now) -> Bool {
        switch self {
        case .thisWeek:
            let week = Self.week(containing: now, calendar: calendar)
            return date >= week.start && date < week.end
        case .allTime: return true
        case .month(let key): return MonthKey(date, calendar: calendar) == key
        }
    }

    var title: String {
        switch self {
        case .thisWeek: "This week"
        case .allTime: "All time"
        case .month(let key): key.longLabel
        }
    }

    /// `period` if it still has data, otherwise All time (e.g. after Exit removed that month).
    static func validated(_ period: Period, in entries: [Entry], calendar: Calendar = .current) -> Period {
        guard case .month(let key) = period else { return period }
        return months(in: entries, calendar: calendar).contains(key) ? period : .allTime
    }

    /// Months that have any entry, newest first.
    static func months(in entries: [Entry], calendar: Calendar = .current) -> [MonthKey] {
        Array(Set(entries.map { MonthKey($0.date, calendar: calendar) })).sorted(by: >)
    }
}

nonisolated enum AllowanceSchedule {
    static let startKey = "weeklyAllowanceStart"

    /// Persist once: reopening the app must never postpone the first Monday reset.
    static func startDate(in defaults: UserDefaults, now: Date = .now, calendar: Calendar = .current) -> Date {
        if let timestamp = defaults.object(forKey: startKey) as? Double {
            return Date(timeIntervalSince1970: timestamp)
        }
        let start = Period.week(containing: now, calendar: calendar).end
        defaults.set(start.timeIntervalSince1970, forKey: startKey)
        return start
    }
}
