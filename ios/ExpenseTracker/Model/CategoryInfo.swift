nonisolated struct CategoryInfo: Hashable, Sendable {
    let name: String
    let icon: String
    let tileHex: String

    static let spending: [CategoryInfo] = [
        .init(name: "Food", icon: "🍜", tileHex: "#ffa26b"), .init(name: "Transport", icon: "🚇", tileHex: "#74c0fc"),
        .init(name: "Shopping", icon: "🛍️", tileHex: "#faa2c1"), .init(name: "Entertainment", icon: "🎬", tileHex: "#e599f7"),
        .init(name: "Bills", icon: "💡", tileHex: "#ffd43b"), .init(name: "Other", icon: "✨", tileHex: "#91a7ff"),
    ]
    static let received: [CategoryInfo] = [
        .init(name: "Allowance", icon: "💵", tileHex: "#8ce99a"), .init(name: "Gift", icon: "🎁", tileHex: "#b2f2bb"),
        .init(name: "Job", icon: "💼", tileHex: "#63e6be"), .init(name: "Other", icon: "✨", tileHex: "#d3f9d8"),
    ]

    var symbol: String {
        switch name {
        case "Food": "fork.knife"
        case "Transport": "tram"
        case "Shopping": "bag"
        case "Entertainment": "play.rectangle"
        case "Bills": "bolt"
        case "Allowance": "wallet.bifold"
        case "Gift": "gift"
        case "Job": "briefcase"
        default: "ellipsis"
        }
    }

    static func list(for kind: Kind) -> [CategoryInfo] { kind == .spent ? spending : received }

    /// The named category of `kind`, or that kind's "Other" for unknown names.
    static func find(_ name: String, kind: Kind) -> CategoryInfo {
        let list = list(for: kind)
        return list.first { $0.name == name } ?? list.last!
    }
}
