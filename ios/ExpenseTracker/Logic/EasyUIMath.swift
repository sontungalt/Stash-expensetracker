import CoreGraphics
import Foundation

/// Neon edge button (EasyUI): where the light beam points, in degrees, `elapsed` seconds in. One lap = 3 s at speed 1.
nonisolated enum NeonBeam {
    static func angle(elapsed: TimeInterval, speed: Double = 1) -> Double {
        let lap = 3 / (speed > 0 ? speed : 1)
        return (elapsed / lap).truncatingRemainder(dividingBy: 1) * 360
    }
}

/// Liquid toggle (EasyUI): the blob outline, rebuilt from a spring's progress every frame.
nonisolated enum LiquidBlob {
    static let pointCount = 12

    /// Mid-flight stretch: 0 at rest, 1 halfway.
    static func stretch(_ t: CGFloat) -> CGFloat { max(0, 4 * t * (1 - t)) }

    /// Outline points: the blob travels from the left end (t = 0) to the right end (t = 1), stretching along the
    /// travel axis and wobbling while it moves, then settles back into a circle.
    static func points(width: CGFloat, height: CGFloat, t: CGFloat, stretch: CGFloat) -> [CGPoint] {
        let pad: CGFloat = 4
        let baseR = (height - pad * 2) / 2
        let leftX = pad + baseR, rightX = width - pad - baseR
        let cx = leftX + (rightX - leftX) * t, cy = height / 2
        let rx = baseR * (1 + stretch * 0.35), ry = baseR * (1 - stretch * 0.12)
        return (0..<pointCount).map { i in
            let a = (CGFloat.pi * 2 * CGFloat(i)) / CGFloat(pointCount) - .pi / 2
            let wob = 1 + stretch * 0.18 * sin(a * 3 + t * .pi * 2)
            return CGPoint(x: cx + cos(a) * rx * wob, y: cy + sin(a) * ry * wob)
        }
    }
}

/// Origin dropdown (EasyUI): where the menu goes relative to its trigger, and which corner it grows from.
nonisolated enum DropdownLayout {
    enum Align: Sendable { case leading, trailing }
    struct Placement: Equatable, Sendable {
        let rect: CGRect
        /// Growth origin as unit coordinates of the menu (0 = left/top, 1 = right/bottom).
        let originX: CGFloat
        let originY: CGFloat
    }

    static func place(anchor: CGRect, size: CGSize, container: CGSize, align: Align, gap: CGFloat = 8, margin: CGFloat = 12) -> Placement {
        let rawX = align == .trailing ? anchor.maxX - size.width : anchor.minX
        let x = min(max(rawX, margin), container.width - margin - size.width)
        let below = anchor.maxY + gap
        let flip = below + size.height > container.height - margin
        let y = flip ? anchor.minY - gap - size.height : below
        return Placement(rect: CGRect(x: x, y: y, width: size.width, height: size.height),
                         originX: align == .trailing ? 1 : 0, originY: flip ? 1 : 0)
    }
}
