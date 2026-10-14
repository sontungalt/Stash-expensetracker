import CryptoKit
import Foundation
import OSLog
import SwiftData

nonisolated struct LegacyRow: Decodable, Equatable, Sendable {
    let id: String
    let description: String
    let amount: Double?
    let category: String
    let date: String
    let sample: Bool?

    private enum Keys: String, CodingKey { case id, description, amount, category, date, sample }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        id = try c.decode(String.self, forKey: .id)
        description = (try? c.decode(String.self, forKey: .description)) ?? ""
        category = (try? c.decode(String.self, forKey: .category)) ?? "Other"
        date = (try? c.decode(String.self, forKey: .date)) ?? ""
        sample = try? c.decode(Bool.self, forKey: .sample)
        if let n = try? c.decode(Double.self, forKey: .amount) { amount = n }
        else if let s = try? c.decode(String.self, forKey: .amount) { amount = Double(s) }
        else { amount = nil }
    }
}

/// Reads the Expo app's AsyncStorage (same app container, same bundle ID) once and copies expenses into SwiftData.
/// Never modifies or deletes the Expo files.
nonisolated enum LegacyImport {
    static let storageKey = "expense-tracker:v1"
    static let doneKey = "legacyImportDone"
    private static let retired = ["Housing": "Bills", "Health": "Other"]
    private static let log = Logger(subsystem: "com.sontungle.expensetracker", category: "LegacyImport")

    enum Outcome: Equatable, Sendable { case alreadyDone, nothingToImport, imported(Int), failed }

    static func defaultDirectory() -> URL {
        URL.applicationSupportDirectory
            .appending(path: Bundle.main.bundleIdentifier ?? "com.sontungle.expensetracker")
            .appending(path: "RCTAsyncLocalStorage_V1")
    }

    /// Rows stored under `storageKey`, or nil when there is no Expo data at all.
    static func readRows(in dir: URL) throws -> [LegacyRow]? {
        let manifestURL = dir.appending(path: "manifest.json")
        guard FileManager.default.fileExists(atPath: manifestURL.path()) else { return nil }
        let manifest = try JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any] ?? [:]
        guard manifest.keys.contains(storageKey) else { return nil }
        let raw: Data
        if let inline = manifest[storageKey] as? String {
            raw = Data(inline.utf8)
        } else {
            let name = Insecure.MD5.hash(data: Data(storageKey.utf8)).map { String(format: "%02x", $0) }.joined()
            raw = try Data(contentsOf: dir.appending(path: name))
        }
        // Decode row by row: one malformed element (missing id, wrong type, null) is skipped, not fatal.
        guard let items = try JSONSerialization.jsonObject(with: raw) as? [Any] else { throw CocoaError(.coderReadCorrupt) }
        return items.compactMap { item in
            guard let dict = item as? [String: Any], let data = try? JSONSerialization.data(withJSONObject: dict),
                  let row = try? JSONDecoder().decode(LegacyRow.self, from: data) else {
                log.warning("Skipped malformed legacy row")
                return nil
            }
            return row
        }
    }

    /// A spending Entry for a legacy row, or nil if the row is unusable (bad date or amount).
    static func entry(from row: LegacyRow, calendar: Calendar = .current) -> Entry? {
        let parts = row.date.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let date = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12)),
              let amount = row.amount, amount > 0,
              let decimal = Decimal(string: String(format: "%.2f", amount)) else { return nil }
        let name = retired[row.category] ?? row.category
        let category = CategoryInfo.find(name, kind: .spent).name
        return Entry(kind: .spent, amount: decimal, category: category, note: row.description, date: date, isSample: row.sample == true)
    }

    @MainActor
    static func run(context: ModelContext, dir: URL = defaultDirectory(), defaults: UserDefaults = .standard, calendar: Calendar = .current) -> Outcome {
        if defaults.bool(forKey: doneKey) { return .alreadyDone }
        do {
            guard let rows = try readRows(in: dir) else { return .nothingToImport }
            var seen = Set(try context.fetch(FetchDescriptor<Transaction>()).compactMap(\.legacyID))
            var added = 0
            for row in rows {
                // legacyID is unique: skip rows already imported and repeats within the file.
                guard seen.insert(row.id).inserted else { continue }
                guard let e = entry(from: row, calendar: calendar) else {
                    log.warning("Skipped unusable legacy row \(row.id, privacy: .public)")
                    continue
                }
                context.insert(Transaction(e, legacyID: row.id))
                added += 1
            }
            try context.save()
            defaults.set(true, forKey: doneKey)
            return .imported(added)
        } catch {
            context.rollback()
            log.error("Legacy import failed: \(error.localizedDescription, privacy: .public)")
            return .failed
        }
    }
}
