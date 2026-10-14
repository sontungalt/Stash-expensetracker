import CoreGraphics
import Foundation
import Testing
@testable import ExpenseTracker

@Suite struct EasyUIPortTests {
    @Test func neonBeamCirclesOncePerThreeSeconds() {
        #expect(NeonBeam.angle(elapsed: 0, speed: 1) == 0)
        #expect(NeonBeam.angle(elapsed: 1.5, speed: 1) == 180)
        #expect(NeonBeam.angle(elapsed: 3, speed: 1) == 0)
        #expect(NeonBeam.angle(elapsed: 0.75, speed: 2) == 180, "speed 2 laps in 1.5 s")
        #expect(NeonBeam.angle(elapsed: 1.5, speed: 0) == 180, "non-positive speed falls back to 1")
    }

    @Test func liquidBlobSitsAtEachEndAndStretchesMidFlight() {
        let (w, h): (CGFloat, CGFloat) = (60, 34)
        func centerX(_ pts: [CGPoint]) -> CGFloat { pts.map(\.x).reduce(0, +) / CGFloat(pts.count) }
        func spanX(_ pts: [CGPoint]) -> CGFloat { pts.map(\.x).max()! - pts.map(\.x).min()! }
        let off = LiquidBlob.points(width: w, height: h, t: 0, stretch: 0)
        let on = LiquidBlob.points(width: w, height: h, t: 1, stretch: 0)
        #expect(off.count == LiquidBlob.pointCount)
        #expect(abs(centerX(off) - 17) < 0.5, "resting off: centered at pad + radius")
        #expect(abs(centerX(on) - 43) < 0.5, "resting on: centered at width - pad - radius")
        let mid = LiquidBlob.points(width: w, height: h, t: 0.5, stretch: LiquidBlob.stretch(0.5))
        #expect(spanX(mid) > spanX(off) * 1.2, "mid-flight the blob stretches along the travel axis")
        #expect(LiquidBlob.stretch(0) == 0 && LiquidBlob.stretch(1) == 0 && LiquidBlob.stretch(0.5) == 1)
    }

    @Test func dropdownOpensBelowAlignedToTheTrigger() {
        let container = CGSize(width: 400, height: 800)
        let trailing = DropdownLayout.place(anchor: CGRect(x: 300, y: 60, width: 80, height: 40), size: CGSize(width: 230, height: 200),
                                            container: container, align: .trailing)
        #expect(trailing.rect == CGRect(x: 150, y: 108, width: 230, height: 200))
        #expect(trailing.originX == 1 && trailing.originY == 0, "grows from its top-right corner")
        let leading = DropdownLayout.place(anchor: CGRect(x: 0, y: 60, width: 80, height: 40), size: CGSize(width: 230, height: 200),
                                           container: container, align: .leading)
        #expect(leading.rect.minX == 12, "kept inside the screen margin")
        #expect(leading.originX == 0)
    }

    @Test func dropdownFlipsAboveWhenThereIsNoRoomBelow() {
        let p = DropdownLayout.place(anchor: CGRect(x: 300, y: 700, width: 80, height: 40), size: CGSize(width: 230, height: 200),
                                     container: CGSize(width: 400, height: 800), align: .trailing)
        #expect(p.rect.maxY == 692)
        #expect(p.originY == 1, "grows from its bottom edge")
    }
}
