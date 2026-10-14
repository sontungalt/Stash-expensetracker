import ActivityKit
import Foundation
import Observation

@MainActor protocol StashActivityClient: AnyObject {
    var isEnabled: Bool { get }
    var isActive: Bool { get }
    func start(_ snapshot: StashBalanceSnapshot) throws
    func update(_ snapshot: StashBalanceSnapshot) async
    func end() async
}

@MainActor final class SystemStashActivityClient: StashActivityClient {
    private var activities: [Activity<StashActivityAttributes>] {
        Activity<StashActivityAttributes>.activities.filter { $0.activityState == .active || $0.activityState == .stale }
    }
    var isEnabled: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }
    var isActive: Bool { !activities.isEmpty }

    nonisolated private static func content(_ snapshot: StashBalanceSnapshot) -> ActivityContent<StashActivityAttributes.ContentState> {
        ActivityContent(state: .init(snapshot: snapshot, updatedAt: .now), staleDate: snapshot.resetAt)
    }

    func start(_ snapshot: StashBalanceSnapshot) throws {
        guard !isActive else { return }
        _ = try Activity.request(attributes: StashActivityAttributes(startedAt: .now), content: Self.content(snapshot), pushType: nil)
    }

    nonisolated func update(_ snapshot: StashBalanceSnapshot) async {
        // Obtain ActivityKit handles on the same executor as its async API.
        for activity in Activity<StashActivityAttributes>.activities {
            if activity.activityState == .ended {
                // iOS can leave an eight-hour-old activity on the Lock Screen for another four hours.
                await activity.end(nil, dismissalPolicy: .immediate)
            } else if activity.activityState == .active || activity.activityState == .stale {
                await activity.update(Self.content(snapshot))
            }
        }
    }

    nonisolated func end() async {
        for activity in Activity<StashActivityAttributes>.activities where activity.activityState != .dismissed {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

@MainActor @Observable final class StashCompanion {
    private(set) var snapshot: StashBalanceSnapshot?
    private(set) var isIslandVisible = false
    private(set) var isBusy = false
    private(set) var errorMessage: String?
    private(set) var reaction: StashPose?
    var isPresented = false
    var pose: StashPose { reaction ?? snapshot?.pose ?? .content }

    @ObservationIgnored private let client: any StashActivityClient
    @ObservationIgnored private var lastDelivered: StashBalanceSnapshot?
    @ObservationIgnored private var updateTask: Task<Void, Never>?
    @ObservationIgnored private var reactionTask: Task<Void, Never>?

    init(client: any StashActivityClient = SystemStashActivityClient()) { self.client = client }

    func refresh(_ value: StashBalanceSnapshot, now: Date = .now) {
        if let previous = snapshot, previous.resetAt <= now, value.resetAt > previous.resetAt { play(.refill) }
        snapshot = value
        isIslandVisible = client.isActive
        if !isIslandVisible { lastDelivered = nil }
        enqueueUpdate()
    }

    func showIsland() {
        guard !isBusy, let snapshot else { return }
        errorMessage = nil
        guard client.isEnabled else {
            errorMessage = "Live Activities are turned off. Enable them for Expense Tracker in Settings, then try again."
            return
        }
        do {
            try client.start(snapshot)
            isIslandVisible = client.isActive
            lastDelivered = nil
            enqueueUpdate()
        } catch {
            isIslandVisible = client.isActive
            errorMessage = "Stash couldn’t open a Live Activity. Please try again with the app open."
        }
    }

    func hideIsland() async {
        guard !isBusy else { return }
        isBusy = true
        // Finish the single update worker before ending, so an older update cannot race a new activity.
        await updateTask?.value
        await client.end()
        isIslandVisible = client.isActive
        lastDelivered = nil
        isBusy = false
        errorMessage = nil
    }

    func open() { errorMessage = nil; isIslandVisible = client.isActive; isPresented = true; play(.waving) }

    func play(_ pose: StashPose) {
        reactionTask?.cancel()
        reaction = pose
        reactionTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(3.2)) } catch { return }
            self?.reaction = nil
        }
    }

    private func enqueueUpdate() {
        guard !isBusy, updateTask == nil, snapshot != lastDelivered else { return }
        updateTask = Task { [weak self] in
            guard let self else { return }
            // Serialize updates and coalesce changes arriving while ActivityKit is suspended.
            while !isBusy, let next = snapshot, next != lastDelivered {
                await client.update(next)
                lastDelivered = next
            }
            isIslandVisible = client.isActive
            updateTask = nil
        }
    }
}
