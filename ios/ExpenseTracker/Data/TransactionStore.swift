import Foundation
import SwiftData

enum StoreError: Error, Equatable { case notFound, alreadyExists }

/// Value snapshot retains import metadata and the original timestamp across undo.
nonisolated struct DeletedTransaction: Sendable {
    let entry: Entry
    let legacyID: String?
    let kindRaw: String
}

/// The only place that writes transactions. Every mutation saves, or rolls back and throws.
@MainActor
final class TransactionStore {
    let context: ModelContext

    init(context: ModelContext) { self.context = context }

    static func makeContainer(inMemory: Bool) throws -> ModelContainer {
        try ModelContainer(for: Transaction.self, configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory))
    }

    func all() throws -> [Entry] {
        try context.fetch(FetchDescriptor<Transaction>(sortBy: [SortDescriptor(\.date, order: .reverse)])).map(\.entry)
    }

    func add(_ e: Entry) throws {
        var e = e
        e.date = Entry.calendarDay(e.date)
        try commit { context.insert(Transaction(e)) }
    }

    func update(id: UUID, with e: Entry) throws {
        let row = try find(id)
        var e = e
        e.date = Entry.calendarDay(e.date)
        try commit { row.apply(e) }
    }

    func delete(id: UUID) throws {
        let row = try find(id)
        try commit { context.delete(row) }
    }

    func deleteForUndo(id: UUID) throws -> DeletedTransaction {
        let row = try find(id)
        let snapshot = DeletedTransaction(entry: row.entry, legacyID: row.legacyID, kindRaw: row.kindRaw)
        try commit { context.delete(row) }
        return snapshot
    }

    func restoreDeleted(_ snapshots: [DeletedTransaction]) throws {
        try commit {
            for snapshot in snapshots {
                let id = snapshot.entry.id
                let descriptor = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == id })
                guard try context.fetchCount(descriptor) == 0 else { throw StoreError.alreadyExists }
                let row = Transaction(snapshot.entry, legacyID: snapshot.legacyID)
                row.kindRaw = snapshot.kindRaw
                context.insert(row)
            }
        }
    }

    func loadSample(now: Date) throws {
        try commit { for e in SampleData.entries(now: now) { context.insert(Transaction(e)) } }
    }

    /// Removes example rows only; the user's own rows stay.
    func exitSample() throws {
        try commit { try context.delete(model: Transaction.self, where: #Predicate { $0.isSample }) }
    }

    func hasSample() throws -> Bool {
        var d = FetchDescriptor<Transaction>(predicate: #Predicate { $0.isSample })
        d.fetchLimit = 1
        return try !context.fetch(d).isEmpty
    }

    private func find(_ id: UUID) throws -> Transaction {
        var d = FetchDescriptor<Transaction>(predicate: #Predicate { $0.id == id })
        d.fetchLimit = 1
        guard let row = try context.fetch(d).first else { throw StoreError.notFound }
        return row
    }

    private func commit(_ change: () throws -> Void) throws {
        do {
            try change()
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }
}
