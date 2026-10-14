import Foundation

nonisolated enum SortOrder: String, CaseIterable, Identifiable, Sendable {
    case newest, oldest, highest, lowest
    var id: String { rawValue }
    var label: String {
        switch self {
        case .newest: "Newest first"
        case .oldest: "Oldest first"
        case .highest: "Highest amount"
        case .lowest: "Lowest amount"
        }
    }
}

nonisolated struct ActivityFilter: Equatable, Sendable {
    var kind: Kind? = nil
    var category: String? = nil
    var search = ""
    var sort: SortOrder = .newest
    var groupByDay = true
}

nonisolated struct DayGroup: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    /// Money out that day (money in is listed but not added).
    let spent: Decimal
    let entries: [Entry]
}

nonisolated enum ActivityQuery {
    /// Today and the preceding six local calendar days. History is retained, never pruned.
    static func lastSevenDays(_ entries: [Entry], now: Date = .now, calendar: Calendar = .current) -> [Entry] {
        let today = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -6, to: today),
              let end = calendar.date(byAdding: .day, value: 1, to: today) else { return [] }
        return entries.filter { $0.date >= start && $0.date < end }
    }

    static func apply(_ f: ActivityFilter, to entries: [Entry]) -> [Entry] {
        let needle = f.search.trimmingCharacters(in: .whitespaces).lowercased()
        let kept = entries.filter { e in
            (f.kind == nil || e.kind == f.kind) &&
            (f.category == nil || (e.category == f.category && (f.kind != nil || e.kind == .spent))) &&
            (needle.isEmpty || e.note.lowercased().contains(needle) || (e.from?.lowercased().contains(needle) ?? false))
        }
        switch f.sort {
        case .newest: return kept.sorted { $0.date > $1.date }
        case .oldest: return kept.sorted { $0.date < $1.date }
        case .highest: return kept.sorted { $0.amount > $1.amount }
        case .lowest: return kept.sorted { $0.amount < $1.amount }
        }
    }

    static func groups(_ entries: [Entry], filter: ActivityFilter, now: Date = .now, calendar: Calendar = .current) -> [DayGroup] {
        let sorted = apply(filter, to: entries)
        let byDate = filter.sort == .newest || filter.sort == .oldest
        guard byDate && filter.groupByDay else {
            let title = byDate ? "All activity" : filter.sort.label
            return sorted.isEmpty ? [] : [DayGroup(id: "all", title: title, spent: spent(sorted), entries: sorted)]
        }
        var order: [Date] = []
        var buckets: [Date: [Entry]] = [:]
        for e in sorted {
            let d = calendar.startOfDay(for: e.date)
            if buckets[d] == nil { order.append(d) }
            buckets[d, default: []].append(e)
        }
        return order.map { d in
            DayGroup(id: ISO8601DateFormatter().string(from: d), title: dayTitle(d, now: now, calendar: calendar),
                     spent: spent(buckets[d]!), entries: buckets[d]!)
        }
    }

    private static func spent(_ entries: [Entry]) -> Decimal {
        entries.filter { $0.kind == .spent }.reduce(Decimal(0)) { $0 + $1.amount }
    }

    static func dayTitle(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let d = calendar.startOfDay(for: date), today = calendar.startOfDay(for: now)
        if d == today { return "Today" }
        if let y = calendar.date(byAdding: .day, value: -1, to: today), d == y { return "Yesterday" }
        let f = DateFormatter()
        f.calendar = calendar
        f.timeZone = calendar.timeZone
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = calendar.component(.year, from: d) == calendar.component(.year, from: today) ? "EEE, MMM d" : "EEE, MMM d yyyy"
        return f.string(from: d)
    }

    /// Up to `limit` distinct notes (and senders, for money in) of `kind`, newest first; case- and whitespace-insensitive.
    static func recents(_ entries: [Entry], kind: Kind, limit: Int = 4) -> [Entry] {
        var seen = Set<String>()
        var out: [Entry] = []
        for e in entries.filter({ $0.kind == kind }).sorted(by: { $0.date > $1.date }) {
            var trimmed = e
            trimmed.note = e.note.trimmingCharacters(in: .whitespaces)
            guard !trimmed.note.isEmpty else { continue }
            // Money in is distinct per note *and* sender ("Weekly allowance" from Mum vs Dad).
            let sender = kind == .received ? "|" + (e.from ?? "").trimmingCharacters(in: .whitespaces).lowercased() : ""
            guard seen.insert(trimmed.note.lowercased() + sender).inserted else { continue }
            out.append(trimmed)
            if out.count == limit { break }
        }
        return out
    }
}
