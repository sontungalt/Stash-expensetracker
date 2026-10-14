import Charts
import SwiftUI

/// Monthly spending bars. Tap a bar to pick that month (sets the period); tap it again for This week.
struct MonthBars: View {
    let data: [MonthTotal]
    @Binding var period: Period
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme.current(scheme)
        let picked: MonthKey? = if case .month(let k) = period { k } else { nil }
        Chart(data) { bar in
            BarMark(x: .value("Month", bar.key.shortLabel), y: .value("Spent", NSDecimalNumber(decimal: bar.total).doubleValue), width: .ratio(0.45))
                .foregroundStyle(picked == nil || picked == bar.key ? t.accent : t.accent.opacity(0.3))
                .clipShape(.rect(topLeadingRadius: 6, topTrailingRadius: 6))
        }
        .chartXScale(domain: data.map(\.key.shortLabel))
        .chartYAxis { AxisMarks(position: .leading) { AxisGridLine(); AxisValueLabel(format: .currency(code: "USD").locale(Locale(identifier: "en_US")).precision(.fractionLength(0))) } }
        .frame(height: 200)
        .chartOverlay { proxy in
            GeometryReader { geo in
                // One invisible button per bar: tap picks that month (tap it again for This week). Buttons cancel
                // cleanly when a scroll starts, so swipes that begin on the chart still scroll the Overview.
                if let plot = proxy.plotFrame {
                    let frame = geo[plot]
                    let slot = frame.width / CGFloat(max(data.count, 1))
                    ForEach(data) { bar in
                        if let x = proxy.position(forX: bar.key.shortLabel) {
                            Button {
                                period = period == .month(bar.key) ? .thisWeek : .month(bar.key)
                            } label: { Color.clear.contentShape(.rect) }
                            .buttonStyle(.plain)
                            .frame(width: slot, height: frame.height)
                            .position(x: frame.minX + x, y: frame.midY)
                            .accessibilityLabel("\(bar.key.longLabel), \(Money.format(bar.total))")
                            .accessibilityAddTraits(period == .month(bar.key) ? .isSelected : [])
                        }
                    }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: period)
        .accessibilityLabel("Monthly spending")
        .accessibilityIdentifier("overview.monthChart")
        .accessibilityValue(data.map { "\($0.key.longLabel) \(Money.format($0.total))" }.joined(separator: ", "))
    }
}
