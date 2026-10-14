import SwiftUI

struct DeletionUndoBanner: View {
    let count: Int
    let deadline: Date
    let onUndo: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let t = Theme.current(scheme)
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "trash").accessibilityHidden(true)
                Text(count == 1 ? "Transaction deleted" : "\(count) transactions deleted")
                    .font(.subheadline.weight(.medium))
                    .accessibilityIdentifier("delete.status")
                Spacer(minLength: 0)
                Button(action: onUndo) {
                    Text("Undo").font(.subheadline.bold())
                        .padding(.horizontal, 14).frame(minHeight: 44)
                        .background(t.onInk.opacity(0.14), in: .capsule)
                        .contentShape(.capsule)
                }
                    .buttonStyle(SoftPressStyle())
                    .accessibilityIdentifier("delete.undo")
                    .accessibilityHint("Restores the deleted transactions. Available for five seconds.")
            }
            .foregroundStyle(t.onInk)
            TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30)) { timeline in
                let remaining = min(1, max(0, deadline.timeIntervalSince(timeline.date) / DeletionUndo.duration))
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(t.onInk.opacity(0.16))
                        Capsule().fill(t.onInk)
                            .frame(width: geometry.size.width * remaining)
                    }
                }
                .frame(height: 3)
            }
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(t.ink, in: .rect(cornerRadius: 24))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
        .padding(.horizontal, 20).padding(.top, 6).padding(.bottom, 8)
    }
}

/// Shared by the tab shell and sheets so opening an editor never hides Undo.
struct DeletionUndoNotice: View {
    @Environment(DeletionUndo.self) private var deletionUndo
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if let deadline = deletionUndo.deadline, deletionUndo.count > 0 {
                DeletionUndoBanner(count: deletionUndo.count, deadline: deadline) {
                    do { try deletionUndo.restore() }
                    catch { errorMessage = "Couldn’t restore the transactions. Please try Undo again." }
                }
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: deletionUndo.count > 0)
        .alert("Couldn’t undo", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: { Text(errorMessage ?? "") }
    }
}
