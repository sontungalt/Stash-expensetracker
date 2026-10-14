import SwiftUI

struct CategoryBars: View {
    let totals: [CategoryTotal]
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let t = Theme.current(scheme)
        let maximum = totals.map { NSDecimalNumber(decimal: $0.value).doubleValue }.max() ?? 1
        let categories = CategoryInfo.spending.map { info in
            CategoryTotal(name: info.name, value: totals.first { $0.name == info.name }?.value ?? 0)
        }
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(totals) { category in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(category.name).font(.headline).foregroundStyle(t.text)
                        Text(Money.format(category.value)).font(.body).foregroundStyle(t.text2)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        } else {
        HStack(alignment: .top, spacing: 10) {
            ForEach(categories) { category in
                let ratio = NSDecimalNumber(decimal: category.value).doubleValue / max(maximum, 0.01)
                VStack(spacing: 10) {
                    Text(Money.format(category.value))
                        .font(.caption2.weight(.medium)).monospacedDigit()
                        .foregroundStyle(t.text).lineLimit(1).minimumScaleFactor(0.65)
                    ZStack(alignment: .bottom) {
                        Capsule().fill(t.bg)
                        Capsule().fill(t.chartColor(category.name))
                            .frame(height: category.value > 0 ? max(8, 145 * ratio) : 0)
                    }
                    .frame(height: 155)
                    Text(category.name == "Entertainment" ? "Fun" : category.name == "Transport" ? "Transit" : category.name)
                        .font(.caption).foregroundStyle(t.text2).lineLimit(1).minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(category.name), \(Money.format(category.value))")
            }
        }
        .padding(.top, 8)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Spending by category")
        }
    }
}
