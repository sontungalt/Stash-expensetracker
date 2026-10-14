import SwiftData
import SwiftUI

@main
struct ExpenseTrackerApp: App {
    private let container: ModelContainer
    private let defaults: UserDefaults
    private static let isUITesting = ProcessInfo.processInfo.arguments.contains("-uiTesting")

    init() {
        // UI tests use isolated preferences, just as they use an in-memory transaction store.
        defaults = Self.isUITesting ? UserDefaults(suiteName: "ExpenseTracker.UITests")! : .standard
        if Self.isUITesting && !ProcessInfo.processInfo.arguments.contains("-keepAllowance") {
            defaults.removeObject(forKey: "weeklyAllowanceAmount")
            defaults.removeObject(forKey: AllowanceSchedule.startKey)
            defaults.removeObject(forKey: CurrentBalance.storageKey)
            if ProcessInfo.processInfo.arguments.contains("-allowanceActive") {
                defaults.set(Period.week(containing: .now).start.timeIntervalSince1970, forKey: AllowanceSchedule.startKey)
            }
        }
        _ = AllowanceSchedule.startDate(in: defaults)
        do {
            container = try TransactionStore.makeContainer(inMemory: Self.isUITesting)
        } catch {
            fatalError("Could not open the expense database: \(error)")
        }
        if !Self.isUITesting {
            _ = LegacyImport.run(context: container.mainContext)
        }
        #if DEBUG
        // Screenshots/QA only: `-seedSample` loads the example data at launch (compiled out of Release).
        if ProcessInfo.processInfo.arguments.contains("-seedSample") {
            try? TransactionStore(context: container.mainContext).loadSample(now: .now)
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            RootView(store: TransactionStore(context: container.mainContext))
                .defaultAppStorage(defaults)
        }
            .modelContainer(container)
    }
}
