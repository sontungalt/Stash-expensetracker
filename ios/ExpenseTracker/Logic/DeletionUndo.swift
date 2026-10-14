import Foundation
import Observation

/// One five-second undo window for the current batch of successful deletions.
@MainActor @Observable
final class DeletionUndo {
    static let duration: TimeInterval = 5
    private(set) var deadline: Date?
    private var deleted: [DeletedTransaction] = []
    @ObservationIgnored private let store: TransactionStore
    @ObservationIgnored private var expiryTask: Task<Void, Never>?
    var count: Int { deleted.count }

    init(store: TransactionStore) { self.store = store }

    func delete(id: UUID, now: Date = .now) throws {
        expire(now: now)
        let snapshot = try store.deleteForUndo(id: id)
        deleted.append(snapshot)
        deadline = now.addingTimeInterval(Self.duration)
        expiryTask?.cancel()
        expiryTask = Task { [weak self] in
            do { try await Task.sleep(for: .seconds(Self.duration)) }
            catch { return }
            self?.expire()
        }
    }

    @discardableResult
    func restore(now: Date = .now) throws -> Bool {
        expire(now: now)
        guard !deleted.isEmpty else { return false }
        try store.restoreDeleted(deleted)
        clear()
        return true
    }

    func expire(now: Date = .now) {
        if let deadline, now >= deadline { clear() }
    }

    func discardSamples() {
        deleted.removeAll { $0.entry.isSample }
        if deleted.isEmpty { clear() }
    }

    private func clear() {
        expiryTask?.cancel()
        expiryTask = nil
        deleted = []
        deadline = nil
    }
}
