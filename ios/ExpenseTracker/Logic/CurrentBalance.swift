import Foundation

/// One current balance for all screens, independent of transaction-list filters.
nonisolated enum CurrentBalance {
    static let storageKey = "currentBalanceCorrection"

    private struct Correction: Codable {
        let offset: Decimal
        let createdAt: Date
        let expiresAt: Date
    }

    static func parseAmount(_ text: String) -> Decimal? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.range(of: #"^[0-9]+(?:[.,][0-9]{1,2})?$"#, options: .regularExpression) != nil,
              let amount = Decimal(string: value.replacingOccurrences(of: ",", with: "."), locale: Locale(identifier: "en_US_POSIX")),
              !amount.isNaN, amount >= 0 else { return nil }
        return amount
    }

    static func totals(_ entries: [Entry], allowance: Decimal, startsOn: Date, correction: String,
                       now: Date = .now, calendar: Calendar = .current) -> Totals {
        var totals = Analytics.weeklyAllowance(entries, amount: allowance, startsOn: startsOn, now: now, calendar: calendar)
        if let saved = try? JSONDecoder().decode(Correction.self, from: Data(correction.utf8)),
           !saved.offset.isNaN, now >= saved.createdAt, now < saved.expiresAt {
            totals.adjustment = saved.offset
        }
        return totals
    }

    /// Always compare with the unadjusted balance, so repeated edits replace the previous correction.
    static func correction(target: Decimal, entries: [Entry], allowance: Decimal, startsOn: Date,
                           now: Date = .now, calendar: Calendar = .current) throws -> String {
        guard !target.isNaN, target >= 0 else { throw CocoaError(.validationNumberTooSmall) }
        let base = Analytics.weeklyAllowance(entries, amount: allowance, startsOn: startsOn, now: now, calendar: calendar)
        let reset = now < startsOn ? startsOn : Period.week(containing: now, calendar: calendar).end
        let saved = Correction(offset: target - base.left, createdAt: now, expiresAt: reset)
        return String(decoding: try JSONEncoder().encode(saved), as: UTF8.self)
    }
}
