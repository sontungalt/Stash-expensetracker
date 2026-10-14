import SwiftUI

struct HeroCard: View {
    let totals: Totals
    let period: Period
    let count: Int
    let delta: Double?
    let scheduledStart: Date?
    let weeklyAmount: Decimal
    let onEditBalance: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(StashCompanion.self) private var stash

    var body: some View {
        let t = Theme.current(scheme)
        let weekly = period == .thisWeek
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(weekly ? "Money left" : "Total spent")
                    .font(.subheadline).foregroundStyle(t.text2)
                Spacer(minLength: 12)
                if weekly {
                    Button(action: onEditBalance) {
                        Group {
                            if typeSize.isAccessibilitySize {
                                Image(systemName: "pencil")
                            } else {
                                Label("Edit", systemImage: "pencil")
                            }
                        }
                        .font(.subheadline.weight(.medium))
                        .frame(minHeight: 32)
                    }
                    .buttonStyle(.glass)
                    .foregroundStyle(t.text)
                    .accessibilityLabel("Edit money left")
                    .accessibilityIdentifier("balance.edit")
                }
            }
            let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4)) : AnyLayout(HStackLayout(alignment: .center, spacing: 8))
            layout {
                Text(weekly ? (totals.isOver ? "Over by \(Money.format(-totals.left))" : Money.format(totals.left)) : Money.format(totals.moneyOut))
                .font(.system(size: 56, weight: .regular)).tracking(-2.5).monospacedDigit()
                .foregroundStyle(t.text).minimumScaleFactor(0.45).lineLimit(1)
                .contentTransition(.numericText())
                .accessibilityIdentifier(weekly ? "hero.left" : "hero.spent")
                if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                Button { stash.open() } label: {
                    StashAnimatedView(pose: weekly ? stash.pose : .chart).frame(width: 82, height: 82)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Meet Stash, \((weekly ? stash.pose : .chart).title)")
                .accessibilityHint("Opens animations and Dynamic Island controls")
                .accessibilityIdentifier("stash.open")
            }
            HStack(spacing: 6) {
                Circle().fill(t.accent).frame(width: 7, height: 7)
                Text(weekly ? "\(Money.format(totals.moneyOut)) spent · \(count) transactions" : "\(count) transactions · \(period.title)")
                    .font(.subheadline).foregroundStyle(t.text2)
            }
            if let scheduledStart {
                Text("First reset: \(scheduledStart.formatted(.dateTime.weekday(.wide).day().month(.wide))) at midnight")
                    .font(.caption).foregroundStyle(t.text2)
                    .accessibilityIdentifier("hero.firstReset")
            } else if weekly {
                Text("\(Money.format(weeklyAmount)) weekly allowance · Resets Monday")
                    .font(.caption).foregroundStyle(t.text2)
            }
            if totals.adjustment != 0 {
                Text("Balance correction: \(Money.format(totals.adjustment))")
                    .font(.caption).foregroundStyle(t.text2)
            }
            if let delta {
                Text("\(delta > 0 ? "↑" : "↓") \(Int(abs(delta)))% spending from last month")
                    .font(.caption).foregroundStyle(t.text2)
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(t.card, in: .rect(cornerRadius: 30))
        .accessibilityElement(children: .contain)
    }
}
