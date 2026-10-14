import CryptoKit
import Foundation
import SwiftData
import Testing
@testable import ExpenseTracker

@MainActor @Suite struct LegacyImportTests {
    let dir = FileManager.default.temporaryDirectory.appending(path: "legacy-\(UUID().uuidString)")
    let defaults = UserDefaults(suiteName: "legacy-\(UUID().uuidString)")!

    private func write(manifest: String, file: String? = nil) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try manifest.write(to: dir.appending(path: "manifest.json"), atomically: true, encoding: .utf8)
        if let file {
            let name = Insecure.MD5.hash(data: Data(LegacyImport.storageKey.utf8)).map { String(format: "%02x", $0) }.joined()
            try file.write(to: dir.appending(path: name), atomically: true, encoding: .utf8)
        }
    }
    private func newContext() throws -> ModelContext { ModelContext(try TransactionStore.makeContainer(inMemory: true)) }

    let rowsJSON = """
    [{"id":"a","description":"Rent","amount":1200,"category":"Housing","date":"2026-10-01"},
     {"id":"b","description":"Pharmacy","amount":"15.20","category":"Health","date":"2026-10-03","sample":true},
     {"id":"c","description":"Lunch","amount":12.5,"category":"Food","date":"2026-10-04"},
     {"id":"d","description":"Broken","amount":5,"category":"Food","date":"not-a-date"}]
    """

    @Test func readsValueStoredInItsOwnFile() throws {
        try write(manifest: #"{"expense-tracker:v1":null}"#, file: rowsJSON)
        #expect(try LegacyImport.readRows(in: dir)?.count == 4)
    }

    @Test func readsValueStoredInlineInTheManifest() throws {
        let inline = try String(data: JSONEncoder().encode([LegacyImport.storageKey: #"[{"id":"x","description":"Tea","amount":3,"category":"Food","date":"2026-10-02"}]"#]), encoding: .utf8)!
        try write(manifest: inline)
        #expect(try LegacyImport.readRows(in: dir)?.map { $0.description } == ["Tea"])
    }

    @Test func missingStorageMeansNothingToImport() throws {
        #expect(try LegacyImport.readRows(in: dir) == nil)
        #expect(LegacyImport.run(context: try newContext(), dir: dir, defaults: defaults, calendar: utc) == .nothingToImport)
    }

    @Test func importsNormalizesSkipsBadRowsAndIsIdempotent() throws {
        try write(manifest: #"{"expense-tracker:v1":null}"#, file: rowsJSON)
        let context = try newContext()
        #expect(LegacyImport.run(context: context, dir: dir, defaults: defaults, calendar: utc) == .imported(3))
        let rows = try context.fetch(FetchDescriptor<Transaction>()).map { $0.entry }.sorted { $0.note < $1.note }
        #expect(rows.map { $0.category } == ["Food", "Other", "Bills"])
        #expect(rows.map { $0.amount } == [Decimal(string: "12.5")!, Decimal(string: "15.2")!, 1200])
        #expect(rows.first { $0.note == "Pharmacy" }?.isSample == true)
        #expect(rows.allSatisfy { $0.kind == .spent })
        #expect(LegacyImport.run(context: context, dir: dir, defaults: defaults, calendar: utc) == .alreadyDone)
        defaults.removeObject(forKey: LegacyImport.doneKey)
        #expect(LegacyImport.run(context: context, dir: dir, defaults: defaults, calendar: utc) == .imported(0), "legacy ids stop duplicates")
        #expect(FileManager.default.fileExists(atPath: dir.appending(path: "manifest.json").path()), "Expo files are untouched")
    }

    @Test func malformedDataFailsWithoutMarkingDone() throws {
        try write(manifest: #"{"expense-tracker:v1":null}"#, file: "{not json")
        #expect(LegacyImport.run(context: try newContext(), dir: dir, defaults: defaults, calendar: utc) == .failed)
        #expect(!defaults.bool(forKey: LegacyImport.doneKey))
    }
}

@MainActor @Suite struct LegacyImportReviewFixTests {
    let dir = FileManager.default.temporaryDirectory.appending(path: "legacy-fix-\(UUID().uuidString)")
    let defaults = UserDefaults(suiteName: "legacy-fix-\(UUID().uuidString)")!

    private func run(_ json: String) throws -> (LegacyImport.Outcome, [Entry]) {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try #"{"expense-tracker:v1":null}"#.write(to: dir.appending(path: "manifest.json"), atomically: true, encoding: .utf8)
        let name = Insecure.MD5.hash(data: Data(LegacyImport.storageKey.utf8)).map { String(format: "%02x", $0) }.joined()
        try json.write(to: dir.appending(path: name), atomically: true, encoding: .utf8)
        let context = ModelContext(try TransactionStore.makeContainer(inMemory: true))
        let outcome = LegacyImport.run(context: context, dir: dir, defaults: defaults, calendar: utc)
        return (outcome, try context.fetch(FetchDescriptor<Transaction>()).map { $0.entry })
    }

    @Test func oneMalformedRowDoesNotBlockTheOthers() throws {
        let (outcome, rows) = try run("""
        [{"description":"No id","amount":3,"category":"Food","date":"2026-10-01"},
         {"id":123,"description":"Numeric id","amount":4,"category":"Food","date":"2026-10-01"},
         null,
         {"id":"ok","description":"Good","amount":5,"category":"Food","date":"2026-10-02"}]
        """)
        #expect(outcome == .imported(1))
        #expect(rows.map { $0.note } == ["Good"])
    }

    @Test func duplicateIdsInTheFileImportOnce() throws {
        let (outcome, rows) = try run("""
        [{"id":"a","description":"First","amount":1,"category":"Food","date":"2026-10-01"},
         {"id":"a","description":"Repeat","amount":2,"category":"Food","date":"2026-10-01"}]
        """)
        #expect(outcome == .imported(1))
        #expect(rows.map { $0.note } == ["First"])
    }
}
