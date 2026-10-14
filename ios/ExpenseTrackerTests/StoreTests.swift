import Foundation
import SwiftData
import Testing
@testable import ExpenseTracker

@MainActor @Suite struct StoreTests {
    let store: TransactionStore
    init() throws { store = TransactionStore(context: ModelContext(try TransactionStore.makeContainer(inMemory: true))) }

    @Test func addEditDelete() throws {
        var lunch = Entry(kind: .spent, amount: 12, category: "Food", note: "Lunch", date: day(2026, 10, 10))
        try store.add(lunch)
        lunch.amount = 13
        lunch.note = "Late lunch"
        try store.update(id: lunch.id, with: lunch)
        #expect(try store.all().map(\.note) == ["Late lunch"])
        #expect(try store.all().first?.amount == 13)
        try store.delete(id: lunch.id)
        #expect(try store.all().isEmpty)
        #expect(throws: StoreError.notFound) { try store.delete(id: UUID()) }
    }

    @Test func exitSampleKeepsOwnRowsAndEditedSamplesStaySample() throws {
        try store.loadSample(now: day(2026, 10, 10))
        let mine = Entry(kind: .received, amount: 20, category: "Gift", note: "From aunt", from: "Aunt", date: day(2026, 10, 9))
        try store.add(mine)
        var sample = try store.all().first { $0.isSample }!
        sample.note = "Edited sample"
        try store.update(id: sample.id, with: sample)
        #expect(try store.all().first { $0.id == sample.id }?.isSample == true)
        #expect(try store.hasSample())
        try store.exitSample()
        #expect(try store.all().map(\.note) == ["From aunt"])
        #expect(try store.hasSample() == false)
    }

    @Test func switchingToSpentClearsFrom() throws {
        var gift = Entry(kind: .received, amount: 20, category: "Gift", note: "Gift", from: "Aunt", date: day(2026, 10, 9))
        try store.add(gift)
        gift.kind = .spent
        gift.category = "Other"
        try store.update(id: gift.id, with: gift)
        #expect(try store.all().first?.from == nil)
    }
}
