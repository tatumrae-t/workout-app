import ActivityKit
import Foundation

/// The rest timer shown on the Lock Screen and in the Dynamic Island.
/// Compiled into both the app and the widget extension.
struct RestActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        var endsAt: Date
        /// The next set, e.g. "Dumbbell Row".
        var nextExercise: String?
        /// e.g. "Set 2 of 3 · 50 lb × 10".
        var nextDetail: String?
    }

    var workoutName: String
}
