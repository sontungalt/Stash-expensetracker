import Foundation
import Testing
@testable import ExpenseTracker

struct StashTests {
    @Test func moodsFollowExactBalanceBoundaries() {
        #expect(StashPose.balanceMood(left: 50, allowance: 50) == .stuffed)
        #expect(StashPose.balanceMood(left: 40, allowance: 50) == .stuffed)
        #expect(StashPose.balanceMood(left: Decimal(string: "39.99")!, allowance: 50) == .happy)
        #expect(StashPose.balanceMood(left: 10, allowance: 50) == .happy)
        #expect(StashPose.balanceMood(left: Decimal(string: "9.99")!, allowance: 50) == .low)
        #expect(StashPose.balanceMood(left: Decimal(string: "1.50")!, allowance: 50) == .low)
        #expect(StashPose.balanceMood(left: 0, allowance: 50) == .broke)
        #expect(StashPose.balanceMood(left: Decimal(string: "-0.01")!, allowance: 50) == .over)
        #expect(StashPose.balanceMood(left: 20, allowance: 0) == .happy)
    }

    @Test func islandContentKeepsCentsAndExpiresAtReset() throws {
        let reset = Date(timeIntervalSince1970: 1_800_000_000)
        let snapshot = StashBalanceSnapshot(left: Decimal(string: "-41.60")!, allowance: 50, resetAt: reset, isSample: false)
        #expect(snapshot.amountText == "$41.60")
        #expect(snapshot.balanceTitle == "Over by")
        #expect(snapshot.pose == .over)
        #expect(!snapshot.isExpired(at: reset.addingTimeInterval(-1)))
        #expect(snapshot.isExpired(at: reset))
        let content = StashActivityAttributes.ContentState(snapshot: snapshot, updatedAt: reset.addingTimeInterval(-10))
        let data = try JSONEncoder().encode(content)
        #expect(try JSONDecoder().decode(StashActivityAttributes.ContentState.self, from: data) == content)
        #expect(data.count < 4_096)
    }

    @Test func originalArtworkHasCompleteFiniteMotionAndValidCrops() throws {
        let artwork = try #require(StashArtwork.shared)
        let manifest = artwork.manifest
        #expect(Set(manifest.poses.map(\.key)) == Set(StashPose.allCases.map(\.rawValue)))
        #expect(manifest.animations.count == 61)
        for pose in manifest.poses {
            #expect(artwork.image(atlas: "body", crop: pose.crop) != nil)
            let motions = [pose.bodyMotion, pose.shadowMotion] + pose.parts.map(\.motion)
            for part in pose.parts { #expect(artwork.image(atlas: part.atlas, crop: part.crop) != nil) }
            for motion in motions {
                #expect(motion.duration > 0)
                if let animation = motion.animation { #expect(manifest.animations[animation] != nil) }
                #expect(manifest.sample(motion, time: nil).transform.isIdentity)
                for tick in 0...24 {
                    let value = manifest.sample(motion, time: Double(tick) / 24 * pose.duration)
                    #expect(value.opacity >= 0 && value.opacity <= 1)
                    let finite = [value.transform.a, value.transform.b, value.transform.c, value.transform.d,
                                  value.transform.tx, value.transform.ty].allSatisfy { $0.isFinite }
                    #expect(finite)
                }
            }
        }
    }

    @Test func disabledActivitiesAndFailedStartsRemainRetryable() async {
        let client = FakeStashClient()
        let stash = StashCompanion(client: client)
        stash.refresh(balance(50))
        client.isEnabled = false
        stash.showIsland()
        #expect(client.starts == 0)
        #expect(stash.errorMessage != nil)
        client.isEnabled = true
        client.failStart = true
        stash.showIsland()
        #expect(!stash.isIslandVisible)
        #expect(stash.errorMessage != nil)
        client.failStart = false
        stash.showIsland()
        stash.showIsland()
        #expect(stash.isIslandVisible)
        #expect(client.starts == 1)
        #expect(stash.errorMessage == nil)
        await stash.hideIsland()
        #expect(!stash.isIslandVisible)
        #expect(client.ends == 1)
    }

    @Test func relaunchReusesExistingActivityAndDismissalDoesNotRestartIt() async {
        let client = FakeStashClient()
        client.isActive = true
        let stash = StashCompanion(client: client)
        stash.refresh(balance(Decimal(string: "1.50")!))
        stash.showIsland()
        await Task.yield()
        #expect(stash.isIslandVisible)
        #expect(client.starts == 0)
        #expect(client.updates.last?.left == Decimal(string: "1.50"))
        client.isActive = false
        stash.refresh(balance(1))
        #expect(!stash.isIslandVisible)
        #expect(client.starts == 0)
    }

    @Test func editsDuringAnUpdateAreDeliveredInOrderAndKeepLatestBalance() async {
        let client = FakeStashClient()
        client.isActive = true
        client.holdFirstUpdate = true
        let stash = StashCompanion(client: client)
        stash.refresh(balance(50))
        while client.pending == nil { await Task.yield() }
        stash.refresh(balance(2))
        stash.refresh(balance(Decimal(string: "1.50")!))
        #expect(client.updates.map(\.left) == [50])
        client.pending?.resume(); client.pending = nil
        while client.updates.count < 2 { await Task.yield() }
        #expect(client.updates.map(\.left) == [50, Decimal(string: "1.50")!])
        await stash.hideIsland()
        #expect(!client.isActive)
        #expect(client.starts == 0)
    }

    @Test func resetRefreshesMoodAndPreviewDoesNotChangeIslandContent() {
        let client = FakeStashClient()
        let stash = StashCompanion(client: client)
        let reset = Date(timeIntervalSince1970: 1_800_000_000)
        stash.refresh(.init(left: 1, allowance: 50, resetAt: reset, isSample: false), now: reset.addingTimeInterval(-1))
        #expect(stash.pose == .low)
        stash.refresh(.init(left: 50, allowance: 50, resetAt: reset.addingTimeInterval(604800), isSample: false), now: reset)
        #expect(stash.pose == .refill)
        stash.play(.goal)
        #expect(stash.snapshot?.pose == .stuffed)
        #expect(stash.snapshot?.left == 50)
        #expect(client.starts == 0)
    }

    private func balance(_ left: Decimal) -> StashBalanceSnapshot {
        .init(left: left, allowance: 50, resetAt: Date(timeIntervalSince1970: 1_900_000_000), isSample: false)
    }
}

@MainActor private final class FakeStashClient: StashActivityClient {
    var isEnabled = true
    var isActive = false
    var failStart = false
    var starts = 0
    var ends = 0
    var updates: [StashBalanceSnapshot] = []
    var holdFirstUpdate = false
    var pending: CheckedContinuation<Void, Never>?
    func start(_ snapshot: StashBalanceSnapshot) throws {
        if failStart { throw CocoaError(.featureUnsupported) }
        if !isActive { starts += 1; isActive = true }
    }
    func update(_ snapshot: StashBalanceSnapshot) async {
        updates.append(snapshot)
        if holdFirstUpdate && updates.count == 1 { await withCheckedContinuation { pending = $0 } }
    }
    func end() async { ends += 1; isActive = false }
}
