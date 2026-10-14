import SwiftUI

struct StashCompanionSheet: View {
    @Environment(StashCompanion.self) private var stash
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    @State private var preview: StashPose?

    var body: some View {
        let t = Theme.current(scheme)
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 4) {
                        Button { preview = nil; stash.play(.waving) } label: {
                            StashAnimatedView(pose: preview ?? stash.pose).frame(width: 180, height: 180)
                        }
                        .buttonStyle(.plain).accessibilityLabel("Say hello to Stash")
                        .accessibilityIdentifier("stash.wave")
                        Text(preview?.title ?? status).font(.title2.weight(.semibold))
                            .accessibilityIdentifier("stash.status")
                        if let snapshot = stash.snapshot {
                            Text("\(snapshot.isSample ? "Sample · " : "")\(snapshot.balanceTitle): \(snapshot.amountText)")
                                .font(.subheadline).foregroundStyle(t.text2)
                                .accessibilityIdentifier("stash.balance")
                        }
                        Text("Your little money companion").font(.caption).foregroundStyle(t.text2)
                    }
                    VStack(alignment: .leading, spacing: 16) {
                        Label("Take Stash with you", systemImage: "pill.fill").font(.headline)
                        Text("Keep Stash and your money left in Dynamic Island and on your Lock Screen.")
                            .font(.subheadline).foregroundStyle(t.text2)
                        Button {
                            if stash.isIslandVisible { Task { await stash.hideIsland() } }
                            else { stash.showIsland() }
                        } label: {
                            HStack {
                                if stash.isBusy { ProgressView() }
                                Text(stash.isIslandVisible ? "Hide from Dynamic Island" : "Show in Dynamic Island")
                            }.frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.glassProminent).controlSize(.large).tint(t.ink)
                        .foregroundStyle(t.onInk).disabled(stash.isBusy || stash.snapshot == nil)
                        .accessibilityIdentifier("stash.island")
                        if let error = stash.errorMessage {
                            Text(error).font(.footnote).foregroundStyle(t.text2).accessibilityIdentifier("stash.error")
                        }
                        Text("Stash stays for up to 8 hours. Open the app after your allowance resets to refresh the balance. Your balance will be visible on the Lock Screen.")
                            .font(.caption).foregroundStyle(t.text2)
                    }
                    .padding(20).background(t.card, in: .rect(cornerRadius: 28))
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Meet every side of Stash").font(.headline)
                        Picker("Animation", selection: $preview) {
                            Text("Follow my balance").tag(Optional<StashPose>.none)
                            ForEach(StashPose.allCases) { pose in Text(pose.title).tag(Optional(pose)) }
                        }
                        .pickerStyle(.menu).tint(t.text)
                        .accessibilityIdentifier("stash.preview")
                        Text("Try a pose here. The Island always follows your balance.")
                            .font(.caption).foregroundStyle(t.text2)
                    }
                    .padding(20).frame(maxWidth: .infinity, alignment: .leading)
                    .background(t.card, in: .rect(cornerRadius: 28))
                }
                .foregroundStyle(t.text).padding(20)
            }
            .background(t.bg).navigationTitle("Meet Stash").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private var status: String {
        switch stash.snapshot?.pose {
        case .stuffed: "Pockets feeling full"
        case .low: "A little left to look after"
        case .broke: "Ready for a fresh start"
        case .over: "Let’s keep an eye on things"
        default: "Looking after your stash"
        }
    }
}
