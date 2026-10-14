import Foundation
import Testing
@testable import ExpenseTracker

@Suite struct SampleDataTests {
    let now = day(2026, 10, 10)

    @Test func everythingIsTaggedSampleAndNothingIsInTheFuture() {
        let s = SampleData.entries(now: now, calendar: utc)
        #expect(!s.isEmpty)
        #expect(s.allSatisfy { $0.isSample })
        #expect(s.allSatisfy { $0.date <= now })
    }

    @Test func spendingMatchesTheExpoSampleSet() {
        let spent = SampleData.entries(now: now, calendar: utc).filter { $0.kind == .spent }
        #expect(spent.count == 69, "Expo sampleExpenses() gives 69 rows for 2026-10-10 12:00 UTC")
        #expect(Set(spent.map(\.category)).isSubset(of: Set(CategoryInfo.spending.map(\.name))))
        #expect(spent.filter { $0.note == "Rent" }.allSatisfy { $0.amount == 1200 }, "rent is never jittered")
        #expect(spent.first { $0.note == "Rent" }?.category == "Bills")
    }

    @Test func weeklyAllowanceFromMumAndOneGift() {
        let received = SampleData.entries(now: now, calendar: utc).filter { $0.kind == .received }
        let allowance = received.filter { $0.category == "Allowance" }
        #expect(allowance.allSatisfy { $0.amount == 50 && $0.from == "Mum" && utc.component(.weekday, from: $0.date) == 2 })
        #expect(allowance.count == 23, "Mondays from May 1 to Oct 10 2026: 4+5+4+5+4+1")
        #expect(received.filter { $0.category == "Gift" }.map(\.amount) == [30])
    }
}
