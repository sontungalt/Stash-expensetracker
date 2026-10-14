import Foundation
import Testing
@testable import ExpenseTracker

@Suite struct PaletteTests {
    @Test(arguments: [Palette.sunny, Palette.nightPop])
    func textPairingsMeetWCAGAA(_ p: Palette.Scheme) {
        let pairs: [(String, String, String)] = [
            ("text/bg", p.text, p.bg), ("text2/bg", p.text2, p.bg), ("text/card", p.text, p.card),
            ("text2/card", p.text2, p.card), ("accentText/bg", p.accentText, p.bg), ("accentText/card", p.accentText, p.card),
            ("onAccent/accent", p.onAccent, p.accent), ("onInk/ink", p.onInk, p.ink), ("good/card", p.good, p.card),
            ("good/bg", p.good, p.bg), ("danger/bg", p.danger, p.bg), ("danger/card", p.danger, p.card),
        ]
        for (name, fg, bg) in pairs {
            #expect(Palette.contrast(fg, bg) >= 4.5, "\(name) \(fg) on \(bg)")
        }
    }

    @Test func inkReadsOnEveryTile() {
        for info in CategoryInfo.spending + CategoryInfo.received {
            #expect(Palette.contrast(Palette.sunny.tileText, info.tileHex) >= 4.5, "\(info.name)")
        }
    }

    @Test func everyCategoryHasAChartColor() {
        #expect(Palette.chartLight.count == CategoryInfo.spending.count)
        #expect(Palette.chartDark.count == CategoryInfo.spending.count)
        #expect(Set(Palette.chartLight).count == CategoryInfo.spending.count)
        #expect(Set(Palette.chartDark).count == CategoryInfo.spending.count)
    }

    @Test func categoriesAreInTheSpecOrder() {
        #expect(CategoryInfo.spending.map(\.name) == ["Food", "Transport", "Shopping", "Entertainment", "Bills", "Other"])
        #expect(CategoryInfo.received.map(\.name) == ["Allowance", "Gift", "Job", "Other"])
        #expect(CategoryInfo.find("Housing", kind: .spent).name == "Other")
    }

    @Test func moneyFormatsDollarsAndSigns() {
        #expect(Money.format(Decimal(string: "1234.5")!) == "$1,234.50")
        #expect(Money.signed(50, kind: .received) == "+$50.00")
        #expect(Money.signed(Decimal(string: "12.3")!, kind: .spent) == "$12.30")
    }
}
