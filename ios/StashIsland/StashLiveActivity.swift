import ActivityKit
import SwiftUI
import WidgetKit

@main struct StashWidgetBundle: WidgetBundle {
    var body: some Widget { StashLiveActivity() }
}

struct StashLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StashActivityAttributes.self) { context in
            HStack(spacing: 14) {
                portrait(context).frame(width: 30, height: 30)
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.isStale ? "Stash needs a refresh" : title(context)).font(.subheadline)
                    Text(context.isStale ? "Open Expense Tracker" : context.state.snapshot.amountText)
                        .font(.title2.weight(.semibold)).monospacedDigit().contentTransition(.numericText())
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
            }
            .padding(18).activityBackgroundTint(Color(red: 0.96, green: 0.94, blue: 0.87))
            .activitySystemActionForegroundColor(.black).foregroundStyle(.black)
            .widgetURL(URL(string: "expensetracker://stash"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    portrait(context).frame(width: 30, height: 30).padding(.top, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.isStale ? "Refresh balance" : title(context)).font(.caption).foregroundStyle(.secondary)
                        Text(context.isStale ? "Open the app" : context.state.snapshot.amountText)
                            .font(.title3.weight(.semibold)).monospacedDigit().contentTransition(.numericText())
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text(context.isStale ? "Your allowance has reset" : "Stash is looking after your balance")
                            .font(.caption).foregroundStyle(.secondary)
                        Spacer(minLength: 4)
                        Link(destination: URL(string: "expensetracker://add")!) {
                            Image(systemName: "plus").font(.body.weight(.semibold)).padding(10)
                        }.accessibilityLabel("Add expense")
                    }
                }
            } compactLeading: {
                portrait(context).frame(width: 24, height: 24)
            } compactTrailing: {
                if context.isStale {
                    Image(systemName: "arrow.clockwise").accessibilityLabel("Open app to refresh balance")
                } else {
                    Text(compactAmount(context)).font(.caption2.weight(.semibold)).monospacedDigit()
                        .lineLimit(1).minimumScaleFactor(0.7).frame(maxWidth: 76)
                        .accessibilityLabel("\(title(context)), \(context.state.snapshot.amountText)")
                }
            } minimal: {
                portrait(context).frame(width: 24, height: 24)
            }
            .widgetURL(URL(string: "expensetracker://stash"))
            .keylineTint(Color(red: 1, green: 0.69, blue: 0.36))
        }
    }

    private func portrait(_ context: ActivityViewContext<StashActivityAttributes>) -> some View {
        StashPortrait(pose: context.isStale ? .sleep : context.state.snapshot.pose)
    }
    private func title(_ context: ActivityViewContext<StashActivityAttributes>) -> String {
        (context.state.snapshot.isSample ? "Sample · " : "") + context.state.snapshot.balanceTitle
    }
    private func compactAmount(_ context: ActivityViewContext<StashActivityAttributes>) -> String {
        let value = context.state.snapshot
        return (value.isSample ? "S · " : "") + (value.left < 0 ? "−" : "") + value.amountText
    }
}
