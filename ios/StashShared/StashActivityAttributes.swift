import ActivityKit
import Foundation

nonisolated struct StashActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let snapshot: StashBalanceSnapshot
        let updatedAt: Date
    }

    let startedAt: Date
}
