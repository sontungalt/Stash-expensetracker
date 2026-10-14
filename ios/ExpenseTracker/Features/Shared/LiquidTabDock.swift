import SwiftUI

/// One glass lens moves continuously between the two destinations.
struct LiquidTabDock: View {
    @Binding var selection: AppTab
    @GestureState private var dragPosition: CGFloat?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .subheadline) private var rowHeight = 56.0
    @ScaledMetric(relativeTo: .subheadline) private var iconSize = 19.0

    // Text-only segments leave room for the screen at accessibility sizes.
    private var tabHeight: CGFloat { typeSize.isAccessibilitySize ? max(56, rowHeight * 0.7) : rowHeight }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let slot = max(0, (width - 6) / 2)
            let resting = selection == .overview ? CGFloat.zero : slot + 6
            let position = min(max(dragPosition ?? resting, 0), slot + 6)
            ZStack(alignment: .leading) {
                lens
                    .frame(width: slot, height: tabHeight)
                    .scaleEffect(x: dragPosition != nil && !reduceMotion ? 1.035 : 1,
                                 y: dragPosition != nil && !reduceMotion ? 1.055 : 1)
                    .offset(x: position)
                    .animation(reduceMotion || dragPosition != nil ? nil : .spring(response: 0.38, dampingFraction: 0.76), value: position)
                    .animation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.72), value: dragPosition != nil)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                HStack(spacing: 6) {
                    tab(.overview, title: "Overview", symbol: "house", highlighted: position < (slot + 6) / 2)
                    tab(.activity, title: "Activity", symbol: "list.bullet.rectangle", highlighted: position >= (slot + 6) / 2)
                }
            }
            .contentShape(.capsule)
            .simultaneousGesture(
                DragGesture(minimumDistance: 8)
                    .updating($dragPosition) { value, state, _ in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        state = resting + value.translation.width
                    }
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        selection = resting + value.translation.width + slot / 2 < width / 2 ? .overview : .activity
                    }
            )
        }
        .frame(height: tabHeight)
        .padding(8)
        .background(Color(hex: "#262725"), in: .capsule)
        .shadow(color: .black.opacity(0.13), radius: 16, y: 8)
        .padding(.horizontal, typeSize.isAccessibilitySize ? 20 : 42)
        .padding(.top, 8).padding(.bottom, 6)
        .sensoryFeedback(.selection, trigger: selection)
    }

    @ViewBuilder private var lens: some View {
        if reduceTransparency {
            Capsule().fill(.white)
        } else {
            Capsule().fill(.white.opacity(0.72))
                .glassEffect(.regular.tint(.white.opacity(0.28)).interactive(), in: .capsule)
        }
    }

    private func tab(_ value: AppTab, title: String, symbol: String, highlighted: Bool) -> some View {
        Button { selection = value } label: {
            Group {
                if typeSize.isAccessibilitySize {
                    Text(title).font(.subheadline.weight(.medium))
                        .lineLimit(1).minimumScaleFactor(0.7)
                } else {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 8) {
                            Image(systemName: symbol).font(.system(size: iconSize, weight: .medium))
                            Text(title).font(.subheadline.weight(.medium))
                        }
                        VStack(spacing: 4) {
                            Image(systemName: symbol).font(.system(size: iconSize, weight: .medium))
                            Text(title).font(.subheadline.weight(.medium)).lineLimit(1)
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
            .foregroundStyle(highlighted ? Color(hex: "#262725") : .white)
            .frame(maxWidth: .infinity).frame(height: tabHeight)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(value == .overview ? "tab.overview" : "tab.activity")
        .accessibilityAddTraits(selection == value ? .isSelected : [])
        .accessibilityHint("Tap or slide to switch tabs")
        .accessibilityShowsLargeContentViewer {
            Label(title, systemImage: symbol)
        }
    }
}
