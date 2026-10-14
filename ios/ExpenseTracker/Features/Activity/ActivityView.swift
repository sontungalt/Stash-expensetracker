import SwiftData
import SwiftUI

struct ActivityView: View {
    let onEdit: (Entry) -> Void
    let onDelete: (Entry) -> Void
    let refreshDate: Date
    @Query(sort: \Transaction.date, order: .reverse) private var rows: [Transaction]
    @Environment(\.colorScheme) private var scheme
    @AppStorage("weeklyAllowanceAmount") private var allowanceText = "50"
    @AppStorage("weeklyAllowanceStart") private var allowanceStart: Double = 0
    @AppStorage(CurrentBalance.storageKey) private var correction = ""
    @State private var filter = ActivityFilter()
    @State private var editingBalance = false

    private var allowance: Decimal { AmountParser.parse(allowanceText) ?? 50 }

    var body: some View {
        TimelineView(.everyMinute) { _ in
            activity(now: max(.now, refreshDate))
        }
        .sheet(isPresented: $editingBalance) {
            MoneyLeftEditor(amount: currentTotals(now: .now).left) { target in
                correction = try CurrentBalance.correction(target: target, entries: rows.map(\.entry), allowance: allowance,
                                                          startsOn: Date(timeIntervalSince1970: allowanceStart))
            }
        }
    }

    private func activity(now: Date) -> some View {
        let t = Theme.current(scheme)
        let all = ActivityQuery.lastSevenDays(rows.map(\.entry), now: now)
        let shown = ActivityQuery.apply(filter, to: all)
        let groups = ActivityQuery.groups(all, filter: filter, now: now)
        return List {
            Section {
                VStack(spacing: 16) {
                    balanceCard(currentTotals(now: now), t)
                    Picker("Show", selection: $filter.kind) {
                        Text("All").tag(Kind?.none)
                        Text("In").tag(Kind?.some(.received))
                        Text("Out").tag(Kind?.some(.spent))
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("activity.kind")
                    .onChange(of: filter.kind) { filter.category = nil }
                    chips(t)
                    if !shown.isEmpty { summary(shown, t) }
                    HStack {
                        Text("Past 7 days").font(.subheadline.weight(.medium)).foregroundStyle(t.text2)
                            .accessibilityIdentifier("activity.period")
                        Spacer()
                        if filter.sort == .newest || filter.sort == .oldest {
                            Text("By day").font(.caption).foregroundStyle(t.text2)
                            LiquidToggle(label: "Group by day", isOn: $filter.groupByDay)
                        }
                    }
                }
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 4, trailing: 20))

            if groups.isEmpty {
                Section {
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").font(.largeTitle).foregroundStyle(t.text2)
                        Text("No matches in the past 7 days").font(.title3.bold()).foregroundStyle(t.text)
                        Button { filter = ActivityFilter(sort: filter.sort, groupByDay: filter.groupByDay) } label: { Text("Clear filters").foregroundStyle(t.onInk) }
                            .buttonStyle(.glassProminent).tint(t.ink)
                            .accessibilityIdentifier("activity.clear")
                    }
                    .frame(maxWidth: .infinity).padding(.vertical, 24)
                }
                .listRowBackground(t.card)
            }
            ForEach(groups) { g in
                Section {
                    ForEach(g.entries) { e in row(e, t) }
                } header: {
                    HStack {
                        Text(g.title.uppercased()).font(.caption.bold()).foregroundStyle(t.text2)
                        Spacer()
                        if g.spent > 0 { Text(Money.format(g.spent)).font(.footnote).monospacedDigit().foregroundStyle(t.text2) }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 20, bottom: 4, trailing: 20))
            }
        }
        .listStyle(.plain)
        .scrollBounceBehavior(.always, axes: .vertical)
        .scrollContentBackground(.hidden)
        .searchable(text: $filter.search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search")
        .navigationTitle("Activity")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                DropdownTrigger(items: SortOrder.allCases.map { order in
                                    DropdownItem(id: order.rawValue, label: order.label, selected: filter.sort == order) { filter.sort = order }
                                },
                                align: .leading, accessibilityText: "Sort: \(filter.sort.label)", identifier: "activity.sort") { open in
                    HStack(spacing: 6) { Image(systemName: "arrow.up.arrow.down"); DropdownChevron(open: open) }
                }
            }
        }
    }

    private func currentTotals(now: Date) -> Totals {
        CurrentBalance.totals(rows.map(\.entry), allowance: allowance, startsOn: Date(timeIntervalSince1970: allowanceStart),
                              correction: correction, now: now)
    }

    private func balanceCard(_ totals: Totals, _ t: Theme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Money left now").font(.subheadline).foregroundStyle(t.text2)
                    Text(totals.isOver ? "Over by \(Money.format(-totals.left))" : Money.format(totals.left))
                        .font(.system(size: 38, weight: .regular)).monospacedDigit().foregroundStyle(t.text)
                        .minimumScaleFactor(0.6).lineLimit(1)
                        .accessibilityIdentifier("activity.left")
                }
                Spacer()
                Button { editingBalance = true } label: {
                    Image(systemName: "pencil").font(.body)
                        .foregroundStyle(t.text).frame(width: 44, height: 44)
                        .background(t.bg, in: .circle)
                }
                .accessibilityLabel("Edit money left")
                .buttonStyle(.borderless)
                .accessibilityIdentifier("balance.edit")
            }
            if totals.adjustment != 0 {
                Text("Balance correction: \(Money.format(totals.adjustment))")
                    .font(.caption).foregroundStyle(t.text2)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.card, in: .rect(cornerRadius: 28))
    }

    private func chips(_ t: Theme) -> some View {
        let list = filter.kind.map(CategoryInfo.list(for:)) ?? CategoryInfo.spending
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("All", on: filter.category == nil, t) { filter.category = nil }
                ForEach(list, id: \.self) { info in
                    chip(info.name, on: filter.category == info.name, t) {
                        filter.category = filter.category == info.name ? nil : info.name
                    }
                }
            }
        }
    }

    private func chip(_ label: String, on: Bool, _ t: Theme, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label).font(.footnote.weight(on ? .bold : .semibold))
                .foregroundStyle(on ? t.onInk : t.text)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(on ? t.ink : t.card, in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func summary(_ shown: [Entry], _ t: Theme) -> some View {
        let totals = Analytics.totals(shown)
        let mix = Analytics.mix(shown)
        return VStack(alignment: .leading, spacing: 8) {
            Text("Transactions · Past 7 days")
                .font(.headline).foregroundStyle(t.text)
            Text("In \(Money.format(totals.moneyIn)) · Out \(Money.format(totals.moneyOut)) · \(shown.count) items")
                .font(.footnote.weight(.semibold)).foregroundStyle(t.text2)
            if !mix.isEmpty {
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(mix, id: \.name) { m in
                            t.chartColor(m.name).frame(width: max(2, (geo.size.width - CGFloat(mix.count - 1) * 2) * m.share))
                        }
                    }
                }
                .frame(height: 10).clipShape(.capsule)
                .accessibilityLabel("Category mix: " + mix.map { "\($0.name) \(Int($0.share * 100))%" }.joined(separator: ", "))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.card, in: .rect(cornerRadius: 28))
    }

    private func row(_ e: Entry, _ t: Theme) -> some View {
        let info = CategoryInfo.find(e.category, kind: e.kind)
        return Button { onEdit(e) } label: {
            HStack(spacing: 12) {
                CategoryTile(info)
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.note).font(.callout.weight(.semibold)).foregroundStyle(t.text).lineLimit(1)
                    Text(e.from.map { "\(info.name) · from \($0)" } ?? info.name).font(.footnote).foregroundStyle(t.text2)
                }
                Spacer()
                Text(Money.signed(e.amount, kind: e.kind)).font(.callout.weight(.medium)).monospacedDigit()
                    .foregroundStyle(e.kind == .received ? t.good : t.text)
            }
            .padding(17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(t.card, in: .rect(cornerRadius: 26))
        }
        .buttonStyle(SoftPressStyle())
        .accessibilityIdentifier("row.\(e.note)")  // on the button: SwiftUI merges a button's label into one element
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) { onDelete(e) } label: {
                Label("Delete", systemImage: "trash")
                    .foregroundStyle(.white)
            }
            .tint(Color(hex: "#C62828"))
            .accessibilityLabel("Delete transaction")
        }
    }

}
