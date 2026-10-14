import SwiftUI

extension Color {
    init(hex: String) {
        let (r, g, b) = Palette.rgb(hex)
        self.init(.sRGB, red: r, green: g, blue: b, opacity: 1)
    }
}

struct Theme {
    let bg, card, line, text, text2, ink, onInk, accent, accentText, onAccent, good, danger, tileText: Color
    let chart: [Color]

    static func current(_ scheme: ColorScheme) -> Theme {
        let p = scheme == .dark ? Palette.nightPop : Palette.sunny
        return Theme(bg: .init(hex: p.bg), card: .init(hex: p.card), line: .init(hex: p.line), text: .init(hex: p.text),
                     text2: .init(hex: p.text2), ink: .init(hex: p.ink), onInk: .init(hex: p.onInk), accent: .init(hex: p.accent),
                     accentText: .init(hex: p.accentText), onAccent: .init(hex: p.onAccent), good: .init(hex: p.good),
                     danger: .init(hex: p.danger), tileText: .init(hex: p.tileText),
                     chart: (scheme == .dark ? Palette.chartDark : Palette.chartLight).map(Color.init(hex:)))
    }

    /// Chart color for a spending category (spec order); unknown names use "Other".
    func chartColor(_ category: String) -> Color {
        let i = CategoryInfo.spending.firstIndex { $0.name == category } ?? CategoryInfo.spending.count - 1
        return chart[i]
    }
}
