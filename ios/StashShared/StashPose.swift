import Foundation

nonisolated enum StashPose: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case happy, stuffed, waving, surprised, thinking, confused, counting, logging, saving
    case chart, locked, goal, low, broke, over, sleep, content, refill

    var id: String { rawValue }
    var title: String {
        switch self {
        case .happy: "Happy"
        case .stuffed: "Stuffed"
        case .waving: "Hello"
        case .surprised: "Surprised"
        case .thinking: "Thinking"
        case .confused: "Confused"
        case .counting: "Counting"
        case .logging: "Logging"
        case .saving: "Saving"
        case .chart: "Chart check"
        case .locked: "Locked"
        case .goal: "Goal reached"
        case .low: "Running low"
        case .broke: "Empty pockets"
        case .over: "Over budget"
        case .sleep: "Sleeping"
        case .content: "Content"
        case .refill: "Monday refill"
        }
    }

    static func balanceMood(left: Decimal, allowance: Decimal) -> Self {
        if left < 0 { return .over }
        if left == 0 { return .broke }
        guard allowance > 0 else { return .happy }
        if left < allowance / 5 { return .low }
        if left >= allowance * 4 / 5 { return .stuffed }
        return .happy
    }
}
