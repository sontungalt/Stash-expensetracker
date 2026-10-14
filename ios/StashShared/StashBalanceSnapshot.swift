import Foundation

nonisolated struct StashBalanceSnapshot: Codable, Hashable, Sendable {
    let left: Decimal
    let allowance: Decimal
    let resetAt: Date
    let isSample: Bool

    var pose: StashPose { .balanceMood(left: left, allowance: allowance) }
    var amountText: String { Money.format(abs(left)) }
    var balanceTitle: String { left < 0 ? "Over by" : "Money left" }
    func isExpired(at date: Date) -> Bool { date >= resetAt }
}
