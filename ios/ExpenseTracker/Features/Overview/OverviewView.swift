import SwiftData
import SwiftUI
import UIKit

struct OverviewView: View {
    let onAdd: (Kind, String?) -> Void
    let onExitSample: () -> Void
    let refreshDate: Date
    @Query(sort: \Transaction.date, order: .reverse) private var rows: [Transaction]
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("weeklyAllowanceAmount") private var allowanceText = "50"
    @AppStorage("weeklyAllowanceStart") private var allowanceStart: Double = 0
    @AppStorage(CurrentBalance.storageKey) private var correction = ""
    @State private var period: Period = .thisWeek
    @State private var errorMessage: String?
    @State private var editingAllowance = false
    @State private var editingBalance = false
    @State private var clockRevision = UUID()

    private var allowance: Decimal { AmountParser.parse(allowanceText) ?? 50 }

    var body: some View {
        let t = Theme.current(scheme)
        let all = rows.map(\.entry)
        TimelineView(.everyMinute) { _ in
            // The scheduled tick can precede a balance correction saved during this minute.
            content(all, t, now: max(.now, refreshDate))
        }
        .id(clockRevision)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { clockRevision = UUID() }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            clockRevision = UUID()
        }
        .navigationTitle("Expense tracker")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $editingAllowance) {
            WeeklyAllowanceEditor(amount: allowance, startsOn: Date(timeIntervalSince1970: allowanceStart)) {
                allowanceText = NSDecimalNumber(decimal: $0).stringValue
            }
        }
        .sheet(isPresented: $editingBalance) {
            MoneyLeftEditor(amount: currentTotals(all, now: .now).left) { target in
                correction = try CurrentBalance.correction(target: target, entries: rows.map(\.entry), allowance: allowance,
                                                          startsOn: Date(timeIntervalSince1970: allowanceStart))
            }
        }
        // With no history left, return to the weekly budget even if the last view was a month.
        .onChange(of: rows.count) {
            period = rows.isEmpty ? .thisWeek : Period.validated(period, in: rows.map(\.entry))
        }
        .toolbar {
            if !all.isEmpty {
                ToolbarItem(placement: .topBarLeading) {
                    DropdownTrigger(items: [DropdownItem(id: "week", label: "This week", icon: "📅", selected: period == .thisWeek) { period = .thisWeek },
                                            DropdownItem(id: "all", label: "All time", icon: "♾️", selected: period == .allTime) { period = .allTime }]
                                        + Period.months(in: all).map { key in
                                            DropdownItem(id: "\(key.year)-\(key.month)", label: key.longLabel, selected: period == .month(key)) { period = .month(key) }
                                        },
                                    align: .leading, accessibilityText: period.title, identifier: "period.menu") { open in
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                            Text(period.title).font(.subheadline.weight(.semibold)).lineLimit(1)
                            DropdownChevron(open: open)
                        }
                    }
                }
            }
        }
        .alert("Couldn’t load sample data", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }

    private func content(_ all: [Entry], _ t: Theme, now: Date) -> some View {
        let startsOn = Date(timeIntervalSince1970: allowanceStart)
        let pending = period == .thisWeek && now < startsOn
        let scoped = Analytics.filter(all, period: pending ? .allTime : period, now: now)
        let totals = period == .thisWeek ? currentTotals(all, now: now) : Analytics.totals(scoped)
        let delta: Double? = if case .month(let k) = period { Analytics.spendingDelta(all, month: k) } else { nil }
        return ScrollView {
            VStack(spacing: 20) {
                HeroCard(totals: totals, period: period, count: scoped.count, delta: delta,
                         scheduledStart: pending ? startsOn : nil, weeklyAmount: allowance) {
                    editingBalance = true
                }
                if period == .thisWeek {
                    Button { editingAllowance = true } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.body).frame(minWidth: 24)
                            ViewThatFits(in: .horizontal) {
                                HStack {
                                    Text("Weekly allowance")
                                    Spacer(minLength: 12)
                                    Text(Money.format(allowance)).monospacedDigit()
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Weekly allowance")
                                    Text(Money.format(allowance)).monospacedDigit()
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                                .foregroundStyle(t.text2)
                        }
                        .font(.subheadline.weight(.medium)).foregroundStyle(t.text)
                        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
                        .background(t.card, in: .rect(cornerRadius: 24))
                    }
                    .buttonStyle(SoftPressStyle())
                    .accessibilityLabel("Edit weekly allowance, \(Money.format(allowance))")
                    .accessibilityIdentifier("allowance.edit")
                }
                if all.isEmpty { empty(t) }
                if !all.isEmpty {
                    card(t) {
                        HStack(alignment: .top) {
                            Text("Where it goes").font(.headline.weight(.medium)).foregroundStyle(t.text)
                            Spacer()
                            Text(pending ? "Before first reset" : period.title).font(.caption).foregroundStyle(t.text2)
                        }
                        let cats = Analytics.categoryTotals(scoped)
                        if cats.isEmpty {
                            Text("No spending in this period.").foregroundStyle(t.text2).frame(maxWidth: .infinity).padding(.vertical, 24)
                        } else { CategoryBars(totals: cats) }
                    }
                    if let top = Analytics.topShare(scoped) {
                        card(t) {
                            HStack(spacing: 14) {
                                Image(systemName: "arrow.up.right").font(.title3)
                                    .foregroundStyle(t.onAccent).frame(width: 44, height: 44).background(t.accent, in: .circle)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(top.name) leads your spending").font(.subheadline.weight(.medium)).foregroundStyle(t.text)
                                    Text("\(top.share)% of spending in this period").font(.caption).foregroundStyle(t.text2)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    card(t) {
                        Text("Monthly spending").font(.headline.weight(.medium)).foregroundStyle(t.text)
                        MonthBars(data: Analytics.monthlySpending(all, endingAt: Analytics.latestMonth(all)), period: $period)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .scrollBounceBehavior(.always, axes: .vertical)
    }

    private func currentTotals(_ entries: [Entry], now: Date) -> Totals {
        CurrentBalance.totals(entries, allowance: allowance, startsOn: Date(timeIntervalSince1970: allowanceStart),
                              correction: correction, now: now)
    }

    private func empty(_ t: Theme) -> some View {
            VStack(spacing: 20) {
                Text("Your spending, at a glance").font(.title2.weight(.semibold)).foregroundStyle(t.text).multilineTextAlignment(.center)
                Text("Tap a category to log your first expense.").font(.subheadline).foregroundStyle(t.text2)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(CategoryInfo.spending.prefix(4), id: \.self) { info in
                        Button { onAdd(.spent, info.name) } label: {
                            HStack(spacing: 12) { CategoryTile(info, size: 36); Text(info.name).font(.subheadline.weight(.semibold)).foregroundStyle(t.text).lineLimit(1).minimumScaleFactor(0.75); Spacer(minLength: 0) }
                                .padding(12).background(t.card, in: .rect(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Add a \(info.name) expense")
                    }
                }
                Button { onAdd(.spent, nil) } label: { Text("Add expense").foregroundStyle(t.onInk).frame(maxWidth: .infinity) }
                    .buttonStyle(.glassProminent).controlSize(.large).tint(t.ink)
                    .accessibilityIdentifier("empty.add")
                Button { loadSample() } label: { Text("Try sample data").foregroundStyle(t.accentText).frame(maxWidth: .infinity) }
                    .buttonStyle(.glass).controlSize(.large)
                    .accessibilityIdentifier("empty.sample")
            }
            .padding(.vertical, 8)
    }

    private func card<C: View>(_ t: Theme, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 10) { content() }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(t.card, in: .rect(cornerRadius: 30))
    }

    private func loadSample() {
        do { try TransactionStore(context: context).loadSample(now: .now) }
        catch { errorMessage = "Your device storage couldn’t be updated. Please try again." }
    }
}

private struct WeeklyAllowanceEditor: View {
    let startsOn: Date
    let onSave: (Decimal) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var amountText: String
    @State private var error: String?

    init(amount: Decimal, startsOn: Date, onSave: @escaping (Decimal) -> Void) {
        self.startsOn = startsOn
        self.onSave = onSave
        _amountText = State(initialValue: NSDecimalNumber(decimal: amount).stringValue)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Weekly amount", text: $amountText)
                        .keyboardType(.decimalPad)
                        .accessibilityLabel("Weekly allowance amount")
                        .accessibilityIdentifier("allowance.amount")
                } footer: {
                    if Date.now < startsOn {
                        Text("Your first allowance starts \(startsOn.formatted(.dateTime.weekday(.wide).day().month(.wide))) at midnight. Changing this amount won’t change your balance until then. After that, it resets every Monday, with no rollover.")
                    } else {
                        Text("Your allowance resets every Monday at midnight, with no rollover. Changing it also updates this week’s money left. Your transaction history stays the same.")
                    }
                }
                if let error { Text(error).foregroundStyle(.red).accessibilityIdentifier("allowance.error") }
            }
            .safeAreaInset(edge: .top, spacing: 0) { DeletionUndoNotice() }
            .navigationTitle("Weekly allowance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let amount = AmountParser.parse(amountText), amount > 0 else {
                            error = "Enter an allowance greater than zero, like 50.00."
                            return
                        }
                        onSave(amount)
                        dismiss()
                    }
                    .accessibilityIdentifier("allowance.save")
                }
            }
        }
    }
}
