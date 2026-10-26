import ActivityKit
import Foundation

/// Starts, updates and ends the rest timer Live Activity.
@MainActor
enum RestActivityController {
    private static var current: Activity<RestActivityAttributes>?

    /// Shows the countdown to `end`, or takes it down when `end` is nil.
    static func show(until end: Date?, for workout: ActiveWorkout) {
        guard let end, end > Date() else {
            stop()
            return
        }
        let state = RestActivityAttributes.ContentState(
            startedAt: current?.content.state.startedAt ?? Date(),
            endsAt: end,
            nextExercise: workout.currentExercise?.displayName,
            nextDetail: nextDetail(for: workout)
        )
        // Once the end passes the widget switches to "Rest's up" by itself.
        let content = ActivityContent(state: state, staleDate: end)

        if let current, current.activityState == .active {
            Task { await current.update(content) }
        } else {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            current = try? Activity.request(
                attributes: RestActivityAttributes(workoutName: workout.day.title),
                content: content
            )
        }
    }

    static func stop() {
        guard let activity = current else { return }
        current = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }

    /// Clears any left over from a previous launch that didn't end cleanly.
    static func endAll() {
        for activity in Activity<RestActivityAttributes>.activities {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private static func nextDetail(for workout: ActiveWorkout) -> String? {
        guard let exercise = workout.currentExercise, let step = workout.currentStep else { return nil }
        let load = exercise.usesWeight
            ? "\(Format.weight(workout.weight)) lb × \(workout.reps)"
            : "\(workout.reps) reps"
        return "Set \(step.setNumber) of \(step.totalSets) · \(load)"
    }
}
