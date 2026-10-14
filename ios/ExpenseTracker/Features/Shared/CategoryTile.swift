import SwiftUI

struct CategoryTile: View {
    let info: CategoryInfo
    var size: CGFloat = 44
    @Environment(\.colorScheme) private var scheme
    init(_ info: CategoryInfo, size: CGFloat = 44) { self.info = info; self.size = size }

    var body: some View {
        let t = Theme.current(scheme)
        Image(systemName: info.symbol)
            .font(.system(size: size * 0.40, weight: .medium))
            .foregroundStyle(info.name == "Food" ? t.onAccent : t.onInk)
            .frame(width: size, height: size)
            .background(info.name == "Food" ? t.accent : t.ink, in: .circle)
            .accessibilityHidden(true)
    }
}
