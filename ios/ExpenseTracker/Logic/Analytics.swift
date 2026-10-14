import Foundation

nonisolated struct Totals: Equatable, Sendable {
    let moneyIn: Decimal
    let moneyOut: Decimal
    var adjustment: Decimal = 0
    var left: Decimal { moneyIn - moneyOut + adjustment }
    var isOver: Bool { left < 0 }
}

nonisolated struct MonthTotal: Identifiable, Equatable, Sendable {
    let key: MonthKey
    let total: Decimal
    var id: MonthKey { key }
}

nonisolated struct CategoryTotal: Identifiable, Equatable, Sendable {
    let name: String
    let value: Decimal
    var id: String { name }
}

nonisolated enum Analytics {
    static func filter(_ entries: [Entry], period: Period, calendar: Calendar = .current, now: Date = .now) -> [Entry] {
        entries.filter { period.contains($0.date, calendar: calendar, now: now) }
    }

    /// Preserve the existing ledger balance until activation, then start fresh each Monday.
    static func weeklyAllowance(_ entries: [Entry], amount: Decimal, startsOn: Date = .distantPast, now: Date = .now, calendar: Calendar = .current) -> Totals {
        guard now >= startsOn else { return totals(entries) }
        let week = filter(entries, period: .thisWeek, calendar: calendar, now: now)
        return Totals(moneyIn: amount, moneyOut: totals(week).moneyOut)
    }

    static func totals(_ entries: [Entry]) -> Totals {
        var moneyIn: Decimal = 0, moneyOut: Decimal = 0
        for e in entries { if e.kind == .received { moneyIn += e.amount } else { moneyOut += e.amount } }
        return Totals(moneyIn: moneyIn, moneyOut: moneyOut)
    }

    /// The month the bar chart ends on: the latest month with data (this month when there is none).
    static func latestMonth(_ entries: [Entry], now: Date = .now, calendar: Calendar = .current) -> MonthKey {
        entries.map { MonthKey($0.date, calendar: calendar) }.max() ?? MonthKey(now, calendar: calendar)
    }

    static func monthlySpending(_ entries: [Entry], endingAt end: MonthKey, count: Int = 6, calendar: Calendar = .current) -> [MonthTotal] {
        var sums: [MonthKey: Decimal] = [:]
        for e in entries where e.kind == .spent { sums[MonthKey(e.date, calendar: calendar), default: 0] += e.amount }
        return (0..<count).map { i in
            let key = end.shifted(i - (count - 1))
            return MonthTotal(key: key, total: sums[key] ?? 0)
        }
    }

    /// Spending per category, biggest first; ties keep the spec's category order.
    static func categoryTotals(_ entries: [Entry]) -> [CategoryTotal] {
        var sums: [String: Decimal] = [:]
        for e in entries where e.kind == .spent { sums[e.category, default: 0] += e.amount }
        let order = CategoryInfo.spending.map(\.name)
        return order.compactMap { name in sums[name].map { CategoryTotal(name: name, value: $0) } }
            .enumerated().sorted { $0.element.value != $1.element.value ? $0.element.value > $1.element.value : $0.offset < $1.offset }
            .map(\.element)
    }

    static func topShare(_ entries: [Entry]) -> (name: String, share: Int)? {
        let cats = categoryTotals(entries)
        guard let top = cats.first else { return nil }
        let total = cats.reduce(Decimal(0)) { $0 + $1.value }
        let share = NSDecimalNumber(decimal: top.value / total * 100).doubleValue.rounded()
        return (top.name, Int(share))
    }

    static func focusCopy(name: String, share: Int) -> String { "\(name) is \(share)% of this period’s spend." }

    private static let quips = [
        "Food": "a well-fed run", "Transport": "always on the move", "Shopping": "treat yourself",
        "Entertainment": "living it up", "Bills": "peak adulting", "Other": "a bit of everything",
    ]

    static func quip(_ entries: [Entry]) -> String {
        guard let top = categoryTotals(entries).first else { return "" }
        return "Mostly \(CategoryInfo.find(top.name, kind: .spent).icon) \(top.name), \(quips[top.name] ?? "")"
    }

    static func mix(_ entries: [Entry]) -> [(name: String, share: Double)] {
        let cats = categoryTotals(entries)
        let total = NSDecimalNumber(decimal: cats.reduce(Decimal(0)) { $0 + $1.value }).doubleValue
        guard total > 0 else { return [] }
        return cats.map { ($0.name, (NSDecimalNumber(decimal: $0.value).doubleValue / total * 100).rounded() / 100) }
    }

    /// Percent change in spending versus the previous month; nil when the previous month had none.
    static func spendingDelta(_ entries: [Entry], month: MonthKey, calendar: Calendar = .current) -> Double? {
        let bars = monthlySpending(entries, endingAt: month, count: 2, calendar: calendar)
        let prev = NSDecimalNumber(decimal: bars[0].total).doubleValue
        let cur = NSDecimalNumber(decimal: bars[1].total).doubleValue
        guard prev > 0 else { return nil }
        return ((cur - prev) / prev * 100).rounded()
    }
}
