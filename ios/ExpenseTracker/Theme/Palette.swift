import Foundation

/// Neutral surfaces and coral accents; text pairings remain contrast-testable.
nonisolated enum Palette {
    struct Scheme: Sendable {
        let bg, card, line, text, text2, ink, onInk, inkShadow, accent, accentShadow, accentText, onAccent, good, danger, tileText: String
    }

    static let sunny = Scheme(
        bg: "#F7F7F5", card: "#FFFFFF", line: "#E5E5E1", text: "#262725", text2: "#646561",
        ink: "#262725", onInk: "#FFFFFF", inkShadow: "#000000", accent: "#E87855", accentShadow: "#D95036",
        accentText: "#AD371F", onAccent: "#262725", good: "#286549", danger: "#B33225", tileText: "#262725")

    static let nightPop = Scheme(
        bg: "#191A18", card: "#262725", line: "#3B3C39", text: "#F5F5F0", text2: "#B4B5AF",
        ink: "#F5F5F0", onInk: "#262725", inkShadow: "#000000", accent: "#EE967C", accentShadow: "#D95036",
        accentText: "#FF9A83", onAccent: "#262725", good: "#91C9AA", danger: "#FF9A83", tileText: "#262725")

    static let heroText = "#262725"
    static let heroPill = "#E5E5E1"

    /// Each category also has a text label and value; color is never the sole identifier.
    static let chartLight = ["#E87855", "#262725", "#8C8E87", "#B3B5AE", "#E8B5A6", "#D5D6D0"]
    static let chartDark = ["#EE967C", "#F5F5F0", "#A7AAA1", "#74776F", "#C95B44", "#50534B"]

    static func rgb(_ hex: String) -> (Double, Double, Double) {
        let n = Int(hex.dropFirst(), radix: 16) ?? 0
        return (Double((n >> 16) & 255) / 255, Double((n >> 8) & 255) / 255, Double(n & 255) / 255)
    }

    /// WCAG 2.x contrast ratio.
    static func contrast(_ a: String, _ b: String) -> Double {
        func lum(_ hex: String) -> Double {
            let (r, g, b) = rgb(hex)
            func ch(_ v: Double) -> Double { v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4) }
            return 0.2126 * ch(r) + 0.7152 * ch(g) + 0.0722 * ch(b)
        }
        let (x, y) = (lum(a), lum(b))
        return (max(x, y) + 0.05) / (min(x, y) + 0.05)
    }
}
