import SwiftUI

/// EasyUI liquid toggle: the blob stretches along its travel and wobbles mid-flight, then settles into a circle.
struct LiquidToggle: View {
    let label: String
    @Binding var isOn: Bool
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        let t = Theme.current(scheme)
        Button { isOn.toggle() } label: {
            ZStack {
                Capsule().fill(t.line)
                HStack {
                    Text("ON").foregroundStyle(t.accentText).opacity(isOn ? 1 : 0)
                    Spacer()
                    Text("OFF").foregroundStyle(t.text2).opacity(isOn ? 0 : 0.8)
                }
                .font(.system(size: 9.5, weight: .heavy))
                .padding(.horizontal, 10)
                BlobShape(progress: isOn ? 1 : 0)
                    .fill(isOn ? t.accent : Color(hex: scheme == .dark ? "#8a7a66" : "#b8a58f"))
            }
            .frame(width: 60, height: 34)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .animation(reduce ? nil : .spring(response: 0.42, dampingFraction: 0.55), value: isOn)
        .sensoryFeedback(.selection, trigger: isOn)
        .accessibilityRepresentation { Toggle(label, isOn: $isOn) }
    }
}

/// The blob outline as an animatable shape: SwiftUI re-runs `path(in:)` every frame of the spring.
nonisolated struct BlobShape: Shape {
    var progress: CGFloat
    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let t = min(max(progress, 0), 1)
        let pts = LiquidBlob.points(width: rect.width, height: rect.height, t: t, stretch: LiquidBlob.stretch(t))
        func mid(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2) }
        var path = Path()
        path.move(to: mid(pts[pts.count - 1], pts[0]))
        for i in pts.indices {
            path.addQuadCurve(to: mid(pts[i], pts[(i + 1) % pts.count]), control: pts[i])
        }
        path.closeSubpath()
        return path.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}
