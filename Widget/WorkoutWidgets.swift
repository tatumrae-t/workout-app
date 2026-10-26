import ActivityKit
import SwiftUI
import WidgetKit

@main
struct WorkoutWidgets: WidgetBundle {
    var body: some Widget {
        RestLiveActivity()
    }
}

struct RestLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestActivityAttributes.self) { context in
            RestLockScreenView(state: context.state, isDone: context.isStale)
                .activityBackgroundTint(Color.black.opacity(0.6))
                .activitySystemActionForegroundColor(.green)
        } dynamicIsland: { context in
            let state = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label(context.isStale ? "Rest's up" : "Rest", systemImage: "timer")
                        .font(.headline)
                        .foregroundStyle(.green)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Countdown(state: state)
                        .font(.title2.monospacedDigit().bold())
                        .frame(maxWidth: 80, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    NextSetView(state: state)
                }
            } compactLeading: {
                Image(systemName: "timer").foregroundStyle(.green)
            } compactTrailing: {
                Countdown(state: state)
                    .monospacedDigit()
                    .frame(maxWidth: 44)
                    .foregroundStyle(.green)
            } minimal: {
                Image(systemName: "timer").foregroundStyle(.green)
            }
        }
    }
}

/// Ticks down on its own, so the app doesn't have to update it every second.
struct Countdown: View {
    let state: RestActivityAttributes.ContentState

    var body: some View {
        Text(timerInterval: state.startedAt...max(state.startedAt, state.endsAt), countsDown: true)
            .multilineTextAlignment(.trailing)
    }
}

struct NextSetView: View {
    let state: RestActivityAttributes.ContentState

    var body: some View {
        if let exercise = state.nextExercise {
            VStack(alignment: .leading, spacing: 2) {
                Text("Next: \(exercise)")
                    .font(.subheadline.bold())
                    .lineLimit(1)
                if let detail = state.nextDetail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct RestLockScreenView: View {
    let state: RestActivityAttributes.ContentState
    let isDone: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label(isDone ? "Rest's up" : "Rest", systemImage: "timer")
                    .font(.headline)
                    .foregroundStyle(.green)
                Spacer()
                Countdown(state: state)
                    .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                    .frame(maxWidth: 120, alignment: .trailing)
            }
            ProgressView(timerInterval: state.startedAt...max(state.startedAt, state.endsAt), countsDown: true) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(.green)
            NextSetView(state: state)
        }
        .padding()
    }
}
