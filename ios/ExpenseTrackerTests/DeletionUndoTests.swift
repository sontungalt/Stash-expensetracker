import Foundation
import SwiftData
import Testing
@testable import ExpenseTracker

@MainActor @Suite struct DeletionUndoTests {
    let store: TransactionStore
    let undo: DeletionUndo
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        store = TransactionStore(context: ModelContext(try TransactionStore.makeContainer(inMemory: true)))
        undo = DeletionUndo(store: store)
    }

    @Test func undoRestoresExactRecordAndBalanceOnce() throws {
        let entry = Entry(kind: .received, amount: 17.35, category: "Gift", note: "Birthday", from: "Mum", date: now, isSample: true)
        store.context.insert(Transaction(entry, legacyID: "old-import-123"))
        try store.context.save()
        try undo.delete(id: entry.id, now: now)
        #expect(try store.all().isEmpty)
        #expect(undo.count == 1)
        #expect(undo.deadline == now.addingTimeInterval(5))
        #expect(try undo.restore(now: now.addingTimeInterval(4.99)))
        let restored = try store.context.fetch(FetchDescriptor<Transaction>()).first!
        #expect(restored.entry == entry)
        #expect(restored.legacyID == "old-import-123")
        #expect(Analytics.totals(try store.all()).left == entry.amount)
        #expect(try undo.restore(now: now.addingTimeInterval(4.99)) == false)
        #expect(try store.all().count == 1)
    }

    @Test func exactlyFiveSecondsEndsUndoWindow() throws {
        let entry = Entry(kind: .spent, amount: 2, category: "Food", note: "Tea", date: now)
        try store.add(entry)
        try undo.delete(id: entry.id, now: now)
        #expect(try undo.restore(now: now.addingTimeInterval(5)) == false)
        #expect(undo.count == 0)
        #expect(try store.all().isEmpty)
    }

    @Test func repeatedDeletesHaveOneFreshWindowAndRestoreTogether() throws {
        let a = Entry(kind: .spent, amount: 2, category: "Food", note: "Tea", date: now)
        let b = Entry(kind: .spent, amount: 3, category: "Transport", note: "Bus", date: now)
        try store.add(a); try store.add(b)
        try undo.delete(id: a.id, now: now)
        try undo.delete(id: b.id, now: now.addingTimeInterval(4))
        undo.expire(now: now.addingTimeInterval(5))
        #expect(undo.count == 2)
        #expect(try undo.restore(now: now.addingTimeInterval(8)))
        #expect(Set(try store.all().map(\.id)) == Set([a.id, b.id]))
    }

    @Test func aNewDeleteDoesNotReviveAnExpiredDeletion() throws {
        let a = Entry(kind: .spent, amount: 2, category: "Food", note: "Tea", date: now)
        let b = Entry(kind: .spent, amount: 3, category: "Food", note: "Coffee", date: now)
        try store.add(a); try store.add(b)
        try undo.delete(id: a.id, now: now)
        try undo.delete(id: b.id, now: now.addingTimeInterval(6))
        #expect(undo.count == 1)
        #expect(try undo.restore(now: now.addingTimeInterval(7)))
        #expect(try store.all().map(\.id) == [b.id])
    }

    @Test func failedDeleteKeepsExistingUndoAvailable() throws {
        let entry = Entry(kind: .spent, amount: 2, category: "Food", note: "Tea", date: now)
        try store.add(entry)
        try undo.delete(id: entry.id, now: now)
        #expect(throws: StoreError.notFound) { try undo.delete(id: UUID(), now: now.addingTimeInterval(1)) }
        #expect(undo.count == 1)
        #expect(undo.deadline == now.addingTimeInterval(5))
        #expect(try undo.restore(now: now.addingTimeInterval(2)))
    }

    @Test func restoreCollisionDoesNotOverwriteOrLoseUndoSnapshot() throws {
        let entry = Entry(kind: .spent, amount: 2, category: "Food", note: "Tea", date: now)
        try store.add(entry)
        try undo.delete(id: entry.id, now: now)
        var replacement = entry
        replacement.note = "New record"
        try store.add(replacement)
        #expect(throws: StoreError.alreadyExists) { try undo.restore(now: now.addingTimeInterval(1)) }
        #expect(undo.count == 1)
        #expect(try store.all().first?.note == "New record")
    }

    @Test func exitingSamplesDoesNotRestoreExampleRows() throws {
        let entry = Entry(kind: .spent, amount: 2, category: "Food", note: "Example", date: now, isSample: true)
        try store.add(entry)
        try undo.delete(id: entry.id, now: now)
        undo.discardSamples()
        #expect(undo.count == 0)
        #expect(try undo.restore(now: now.addingTimeInterval(1)) == false)
    }
}
