import SwiftData
import SwiftUI
import UIKit

enum SheetRequest: Identifiable {
    case add(kind: Kind, category: String?)
    case edit(Entry)
    var id: String {
        switch self {
        case .add(let kind, let category): "add-\(kind.rawValue)-\(category ?? "")"
        case .edit(let e): "edit-\(e.id)"
        }
    }
}

enum AppTab: Hashable { case overview, activity }

struct RootView: View {
    let store: TransactionStore
    @State private var deletionUndo: DeletionUndo
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .overview
    @State private var sheet: SheetRequest?
    @State private var errorMessage: String?
    @State private var dropdowns = DropdownCenter()
    @State private var stash = StashCompanion()
    @State private var clockRevision = Date.now
    @Query private var allRows: [Transaction]
    @AppStorage("weeklyAllowanceAmount") private var allowanceText = "50"
    @AppStorage("weeklyAllowanceStart") private var allowanceStart: Double = 0
    @AppStorage(CurrentBalance.storageKey) private var correction = ""
    @Query(filter: #Predicate<Transaction> { $0.isSample }) private var samples: [Transaction]
    @Environment(\.colorScheme) private var scheme

    init(store: TransactionStore) {
        self.store = store
        _deletionUndo = State(initialValue: DeletionUndo(store: store))
    }

    var body: some View {
        let t = Theme.current(scheme)
        TabView(selection: $tab) {
            Tab("Overview", systemImage: "square.grid.2x2.fill", value: AppTab.overview) {
                screen { OverviewView(onAdd: { sheet = .add(kind: $0, category: $1) }, onExitSample: exitSample, refreshDate: clockRevision) }
            }
            Tab("Activity", systemImage: "list.bullet", value: AppTab.activity) {
                screen { ActivityView(onEdit: { sheet = .edit($0) }, onDelete: delete, refreshDate: clockRevision) }
            }
        }
        .tint(t.ink)
        .safeAreaInset(edge: .top, spacing: 0) { DeletionUndoNotice() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { deletionUndo.expire(); clockRevision = .now; stash.refresh(balanceSnapshot) }
        }
        .onChange(of: balanceSnapshot, initial: true) { _, snapshot in stash.refresh(snapshot) }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { date in
            if scenePhase == .active { clockRevision = date; stash.refresh(balanceSnapshot) }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            clockRevision = .now; stash.refresh(balanceSnapshot)
        }
        .onOpenURL { url in
            guard url.scheme == "expensetracker" else { return }
            Task {
                let dismissingSheet = sheet != nil || stash.isPresented
                sheet = nil; stash.isPresented = false
                if dismissingSheet { try? await Task.sleep(for: .milliseconds(400)) }
                if url.host == "add" { sheet = .add(kind: .spent, category: nil) }
                else if url.host == "stash" { stash.open() }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { LiquidTabDock(selection: $tab) }
        .overlay { DropdownOverlay() }
        .environment(dropdowns)
        #if DEBUG
        // Screenshots/QA only: `-tab activity` opens Activity; `-sheet spent|received` opens the add sheet.
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-tab"), args.indices.contains(i + 1), args[i + 1] == "activity" { tab = .activity }
            if let i = args.firstIndex(of: "-sheet"), args.indices.contains(i + 1), let k = Kind(rawValue: args[i + 1]) { sheet = .add(kind: k, category: nil) }
        }
        #endif
         .sheet(item: $sheet) { request in
            AddSheet(request: request, store: store, onDelete: { try deletionUndo.delete(id: $0.id) })
                .safeAreaInset(edge: .top, spacing: 0) { DeletionUndoNotice() }
        }
        .sheet(isPresented: $stash.isPresented) { StashCompanionSheet() }
        .alert("Couldn’t update your data", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
        .environment(deletionUndo)
        .environment(stash)
    }

    private var balanceSnapshot: StashBalanceSnapshot {
        _ = clockRevision
        let now = Date.now
        let allowance = AmountParser.parse(allowanceText) ?? 50
        let start = Date(timeIntervalSince1970: allowanceStart)
        let totals = CurrentBalance.totals(allRows.map(\.entry), allowance: allowance, startsOn: start, correction: correction, now: now)
        return StashBalanceSnapshot(left: totals.left, allowance: allowance,
                                    resetAt: now < start ? start : Period.week(containing: now).end,
                                    isSample: allRows.contains(where: \.isSample))
    }

    /// Wraps a tab's screen in a navigation stack with the sample banner and the + button.
    private func screen<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        let t = Theme.current(scheme)
        return NavigationStack {
            content()
                .refreshable { await refresh() }
                .safeAreaInset(edge: .top) {
                    if !samples.isEmpty { SampleBanner(onExit: exitSample).padding(.horizontal, 20) }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { sheet = .add(kind: .spent, category: nil) } label: {
                            Image(systemName: "plus")
                                .foregroundStyle(t.text).frame(width: 44, height: 44)
                                .background(t.card, in: .circle)
                                .contentShape(.circle)
                        }
                            .buttonStyle(SoftPressStyle())
                            .accessibilityLabel("Add")
                            .accessibilityIdentifier("add")
                    }
                }
                .toolbar(.hidden, for: .tabBar)
                .background(t.bg.ignoresSafeArea())
        }
    }

    private func refresh() async {
        // Queries already observe local transactions. Refresh the clock-dependent
        // totals and companion without recreating the tabs or their filters.
        deletionUndo.expire()
        clockRevision = .now
        stash.refresh(balanceSnapshot)
    }

    private func delete(_ entry: Entry) {
        do {
            try deletionUndo.delete(id: entry.id)
        } catch {
            errorMessage = "Your transaction couldn’t be deleted. Please try again."
        }
    }

    private func exitSample() {
        do {
            try store.exitSample()
            deletionUndo.discardSamples()
            tab = .overview
        } catch {
            errorMessage = "The sample data couldn’t be removed. Please try again."
        }
    }
}
