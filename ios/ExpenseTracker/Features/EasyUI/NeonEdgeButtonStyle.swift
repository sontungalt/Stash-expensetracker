import SwiftUI

/// EasyUI neon edge button: a restrained light travels around the rim while the label stays primary.
/// The web original rotates a conic gradient behind a 1px rim; SwiftUI's AngularGradient does the same natively.
struct NeonEdgeButtonStyle: ButtonStyle {
    var color: Color
    var beam: Color = Color(hex: "#fff6e9")
    var shadow: Color = Color(hex: Palette.sunny.accentShadow)
    var speed: Double = 1

    func makeBody(configuration: Configuration) -> some View {
        NeonEdgeBody(configuration: configuration, color: color, beam: beam, shadow: shadow, speed: speed)
    }
}

private struct NeonEdgeBody: View {
    let configuration: ButtonStyle.Configuration
    let color, beam, shadow: Color
    let speed: Double
    @Environment(\.accessibilityReduceMotion) private var reduce

    var body: some View {
        configuration.label
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Capsule().fill(color))
            .overlay {
                if reduce {
                    Capsule().strokeBorder(beam.opacity(0.4), lineWidth: 2)
                } else {
                    TimelineView(.animation) { context in
                        let angle = NeonBeam.angle(elapsed: context.date.timeIntervalSinceReferenceDate, speed: speed)
                        // Transparent until 280°, bright at 340°, cut at 360°: the same lit arc as the original.
                        Capsule().strokeBorder(
                            AngularGradient(stops: [.init(color: beam.opacity(0), location: 0),
                                                    .init(color: beam.opacity(0), location: 280.0 / 360),
                                                    .init(color: beam.opacity(0.95), location: 340.0 / 360),
                                                    .init(color: beam.opacity(0), location: 1)],
                                            center: .center, angle: .degrees(angle)),
                            lineWidth: 2)
                    }
                    .allowsHitTesting(false)
                }
            }
            .compositingGroup()
            .shadow(color: shadow, radius: 0, x: 0, y: configuration.isPressed ? 0 : 4)
            .offset(y: configuration.isPressed ? 3 : 0)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
