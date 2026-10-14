import Foundation

/// Plain value used by all logic and tests; `Transaction` (SwiftData) maps to and from it.
nonisolated struct Entry: Identifiable, Equatable, Sendable {
    var id: UUID = UUID()
    var kind: Kind
    var amount: Decimal
    var category: String
    var note: String
    var from: String? = nil
    var date: Date
    var isSample: Bool = false

    /// The calendar day of `date`, anchored at noon so small time-zone moves don't shift it to another day.
    static func calendarDay(_ date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(bySettingHour: 12, minute: 0, second: 0, of: calendar.startOfDay(for: date)) ?? date
    }
}
