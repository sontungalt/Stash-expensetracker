import Foundation

nonisolated enum Money {
    private static let style = Decimal.FormatStyle.Currency(code: "USD", locale: Locale(identifier: "en_US"))

    static func format(_ d: Decimal) -> String { d.formatted(style) }

    /// Money in is shown with a leading "+"; money out is shown as a plain amount.
    static func signed(_ d: Decimal, kind: Kind) -> String { kind == .received ? "+" + format(d) : format(d) }
}
