import SwiftUI

struct SampleBanner: View {
    let onExit: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        let t = Theme.current(scheme)
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Sample data").font(.subheadline.bold()).foregroundStyle(t.text)
            }
            Spacer()
            Button(action: onExit) { Text("Exit").foregroundStyle(t.onInk) }
                .buttonStyle(.glassProminent)
                .tint(t.ink)
                .accessibilityIdentifier("sample.exit")
                .accessibilityHint("Removes the example data and returns to Overview")
        }
        .padding(14)
        .background(t.card, in: .rect(cornerRadius: 20))
    }
}
