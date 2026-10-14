import Foundation
import SwiftData

@Model
final class Transaction {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var amount: Decimal
    var category: String
    var note: String
    var from: String?
    var date: Date
    var isSample: Bool
    var legacyID: String?

    init(_ entry: Entry, legacyID: String? = nil) {
        id = entry.id
        kindRaw = entry.kind.rawValue
        amount = entry.amount
        category = entry.category
        note = entry.note
        from = entry.from
        date = entry.date
        isSample = entry.isSample
        self.legacyID = legacyID
    }

    var entry: Entry {
        Entry(id: id, kind: Kind(rawValue: kindRaw) ?? .spent, amount: amount, category: category,
              note: note, from: from, date: date, isSample: isSample)
    }

    /// Overwrite the editable fields; `id`, `isSample` and `legacyID` are kept.
    func apply(_ e: Entry) {
        kindRaw = e.kind.rawValue
        amount = e.amount
        category = e.category
        note = e.note
        from = e.kind == .received ? e.from : nil
        date = e.date
    }
}
