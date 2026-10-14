import SwiftUI

/// One row in an origin dropdown.
struct DropdownItem: Identifiable {
    let id: String
    let label: String
    var icon: String? = nil
    var selected = false
    let action: () -> Void
}

/// EasyUI origin dropdown: the menu grows out of the trigger's own corner (scale 0.96 → 1, an 8pt slide,
/// snappy spring) and the trigger's chevron flips. One menu is open at a time, drawn above the tabs.
@Observable
final class DropdownCenter {
    struct Menu {
        let id: UUID
        let anchor: CGRect
        let items: [DropdownItem]
        let align: DropdownLayout.Align
    }

    private(set) var menu: Menu?
    var openID: UUID? { menu?.id }

    func toggle(id: UUID, anchor: CGRect, items: [DropdownItem], align: DropdownLayout.Align) {
        menu = menu?.id == id ? nil : Menu(id: id, anchor: anchor, items: items, align: align)
    }

    func hide() { menu = nil }
}

/// The button that opens a dropdown. `label` receives whether its menu is open (for the chevron).
struct DropdownTrigger<Label: View>: View {
    let items: [DropdownItem]
    var align: DropdownLayout.Align = .trailing
    let accessibilityText: String
    let identifier: String
    @ViewBuilder let label: (Bool) -> Label
    @Environment(DropdownCenter.self) private var center
    @State private var frame: CGRect = .zero
    @State private var id = UUID()

    var body: some View {
        let open = center.openID == id
        Button { center.toggle(id: id, anchor: frame, items: items, align: align) } label: { label(open) }
            .background(GeometryReader { geo in
                Color.clear
                    .onAppear { frame = geo.frame(in: .global) }
                    .onChange(of: geo.frame(in: .global)) { _, new in frame = new }
            })
            .accessibilityLabel(accessibilityText)
            .accessibilityHint("Opens a menu")
            .accessibilityAddTraits(open ? .isSelected : [])
            .accessibilityIdentifier(identifier)
    }
}

/// A chevron that flips while its menu is open.
struct DropdownChevron: View {
    let open: Bool
    var body: some View {
        Image(systemName: "chevron.down")
            .font(.caption2.weight(.heavy))
            .rotationEffect(.degrees(open ? 180 : 0))
            .animation(.spring(response: 0.3, dampingFraction: 0.75), value: open)
    }
}

/// Draws the open menu above everything; put it in an overlay at the root.
struct DropdownOverlay: View {
    @Environment(DropdownCenter.self) private var center
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        GeometryReader { geo in
            if let menu = center.menu {
                let t = Theme.current(scheme)
                let size = CGSize(width: 240, height: min(CGFloat(menu.items.count) * 48 + 12, 360))
                let origin = geo.frame(in: .global).origin
                let p = DropdownLayout.place(anchor: menu.anchor.offsetBy(dx: -origin.x, dy: -origin.y), size: size,
                                             container: geo.size, align: menu.align)
                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.12)
                        .contentShape(.rect)
                        .onTapGesture { center.hide() }
                        .accessibilityLabel("Close menu")
                        .accessibilityAddTraits(.isButton)
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(Array(menu.items.enumerated()), id: \.element.id) { index, item in
                                Button {
                                    center.hide()
                                    item.action()
                                } label: {
                                    HStack(spacing: 12) {
                                        if let icon = item.icon { Text(icon).frame(width: 24) }
                                        Text(item.label).font(.callout.weight(item.selected ? .bold : .regular)).foregroundStyle(t.text)
                                        Spacer()
                                        if item.selected { Image(systemName: "checkmark").font(.footnote.weight(.heavy)).foregroundStyle(t.accentText) }
                                    }
                                    .padding(.horizontal, 16)
                                    .frame(height: 48)
                                    .contentShape(.rect)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(item.label)
                                .accessibilityAddTraits(item.selected ? .isSelected : [])
                                .accessibilityIdentifier("dropdown.item.\(index)")
                            }
                        }
                        .padding(.vertical, 6)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(width: size.width, height: size.height)
                    .background(t.card, in: .rect(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.18), radius: 18, y: 10)
                    .offset(x: p.rect.minX, y: p.rect.minY)
                    .transition(.scale(scale: 0.96, anchor: UnitPoint(x: p.originX, y: p.originY))
                        .combined(with: .opacity)
                        .combined(with: .offset(y: p.originY == 0 ? -8 : 8)))
                    .accessibilityAddTraits(.isModal)
                    .accessibilityAction(.escape) { center.hide() }
                }
            }
        }
        .ignoresSafeArea()
        // A dismissed menu may still be fading out; it must not swallow the next toolbar tap.
        .allowsHitTesting(center.menu != nil)
        .animation(reduce ? .easeOut(duration: 0.15) : .spring(response: 0.3, dampingFraction: 0.82), value: center.openID)
        .sensoryFeedback(.selection, trigger: center.openID)
    }
}
