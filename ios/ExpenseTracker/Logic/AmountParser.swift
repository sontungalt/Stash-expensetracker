import Foundation

/// Strict parsing of a typed or pasted amount: digits with an optional "." or "," decimal part;
/// "1,234.50" (comma grouping + dot decimal) is accepted. Anything else is rejected rather than truncated.
nonisolated enum AmountParser {
    static func parse(_ text: String) -> Decimal? {
        var s = text.trimmingCharacters(in: .whitespaces)
        if s.contains(".") && s.contains(",") { s = s.replacingOccurrences(of: ",", with: "") }
        else { s = s.replacingOccurrences(of: ",", with: ".") }
        guard s.range(of: #"^[0-9]+(\.[0-9]+)?$"#, options: .regularExpression) != nil,
              var value = Decimal(string: s, locale: Locale(identifier: "en_US")), value > 0 else { return nil }
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 2, .plain)
        return rounded
    }
}
