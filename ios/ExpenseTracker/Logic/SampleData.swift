import Foundation

/// Example data for "Try sample data": the Expo app's 6 months of spending plus money in.
nonisolated enum SampleData {
    private static let rows: [(String, Decimal, String, Int)] = [
        ("Groceries", Decimal(string: "84.3")!, "Food", 2), ("Coffee", Decimal(string: "4.5")!, "Food", 1), ("Dinner out", 46, "Food", 9),
        ("Metro card", 40, "Transport", 3), ("Ride share", Decimal(string: "18.75")!, "Transport", 12),
        ("Rent", 1200, "Bills", 1), ("Sneakers", Decimal(string: "89.99")!, "Shopping", 10), ("Movie night", 24, "Entertainment", 6),
        ("Pharmacy", Decimal(string: "15.2")!, "Other", 14), ("Electricity", Decimal(string: "62.4")!, "Bills", 5),
        ("Internet", 45, "Bills", 7), ("Gift", 30, "Other", 18),
    ]

    static func entries(now: Date, calendar: Calendar = .current) -> [Entry] {
        let thisMonth = MonthKey(now, calendar: calendar)
        var out: [Entry] = []
        for back in 0..<6 {
            let m = thisMonth.shifted(-back)
            for (note, amount, category, dayOfMonth) in rows {
                guard let date = calendar.date(from: DateComponents(year: m.year, month: m.month, day: dayOfMonth, hour: 12)),
                      date <= now else { continue }
                let jitter = Decimal(1) + Decimal(((back * 7 + dayOfMonth * 3) % 11) - 5) / 40
                var value = note == "Rent" ? amount : amount * jitter
                var rounded = Decimal()
                NSDecimalRound(&rounded, &value, 2, .plain)
                out.append(Entry(kind: .spent, amount: rounded, category: category, note: note, date: date, isSample: true))
            }
        }
        // Weekly allowance from Mum every Monday over the same 6 months.
        let start = calendar.date(from: DateComponents(year: thisMonth.shifted(-5).year, month: thisMonth.shifted(-5).month, day: 1, hour: 12))!
        var monday = calendar.nextDate(after: start.addingTimeInterval(-86_400), matching: DateComponents(hour: 12, weekday: 2), matchingPolicy: .nextTime)!
        while monday <= now {
            out.append(Entry(kind: .received, amount: 50, category: "Allowance", note: "Weekly allowance", from: "Mum", date: monday, isSample: true))
            monday = calendar.date(byAdding: .day, value: 7, to: monday)!
        }
        // One gift on the most recent 15th.
        var giftMonth = thisMonth
        if calendar.component(.day, from: now) < 15 { giftMonth = thisMonth.shifted(-1) }
        let giftDate = calendar.date(from: DateComponents(year: giftMonth.year, month: giftMonth.month, day: 15, hour: 12))!
        out.append(Entry(kind: .received, amount: 30, category: "Gift", note: "Birthday money", from: "Grandma", date: giftDate, isSample: true))
        return out
    }
}
