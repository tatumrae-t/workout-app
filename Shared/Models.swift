import Foundation

/// One completed set. Weights are in pounds; 0 means bodyweight or a band.
struct LoggedSet: Codable, Hashable, Identifiable {
    var id = UUID()
    var weight: Double
    var reps: Int
    var completedAt = Date()
    /// How hard the set felt, 5–10 (see `Effort`). Nil when not recorded,
    /// which also keeps older saved sets decoding.
    var rpe: Double? = nil
}

struct LoggedExercise: Codable, Hashable, Identifiable {
    var id = UUID()
    /// Uses Strong's exercise names so imported history lines up with the plan.
    var name: String
    var sets: [LoggedSet]

    /// Heaviest set, with reps breaking ties.
    var bestSet: LoggedSet? {
        sets.max { ($0.weight, $0.reps) < ($1.weight, $1.reps) }
    }
}

enum WorkoutSource: String, Codable {
    case phone, watch, strong
}

struct Workout: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    /// The plan day ("A" or "B") this workout followed, if any.
    var dayID: String?
    var startDate: Date
    var endDate: Date
    var source: WorkoutSource
    var exercises: [LoggedExercise]
    /// Time spent paused, left out of the duration. Nil for older workouts.
    var pausedTime: TimeInterval? = nil

    var duration: TimeInterval { endDate.timeIntervalSince(startDate) - (pausedTime ?? 0) }
    var setCount: Int { exercises.reduce(0) { $0 + $1.sets.count } }
}

/// One exercise in the plan, with the target for each set.
struct PlanExercise: Codable, Hashable, Identifiable {
    var id: String
    /// Strong's name for the exercise, used to match history.
    var name: String
    var displayName: String
    var sets: Int
    var repsLow: Int
    var repsHigh: Int
    /// Week 1 load in pounds, or nil for bodyweight and band exercises.
    var weight: Double?
    /// What to use when there's no weight, e.g. "light band".
    var loadNote: String? = nil
    var restSeconds: Int
    /// Exercises sharing a group are done back to back, alternating sets.
    var supersetGroup: String? = nil
    var perSide: Bool = false
    var isOptional: Bool = false

    var usesWeight: Bool { weight != nil }
    var isDumbbell: Bool { name.contains("(Dumbbell)") }

    var repsText: String {
        let range = repsLow == repsHigh ? "\(repsLow)" : "\(repsLow)–\(repsHigh)"
        return perSide ? "\(range) each side" : range
    }

    var targetText: String {
        "\(sets) × \(repsText)"
    }
}

struct PlanDay: Codable, Hashable, Identifiable {
    var id: String
    var name: String
    /// Unlogged warm-up to do first.
    var warmupNote: String
    var exercises: [PlanExercise]

    var title: String { "Day \(id): \(name)" }

    func exercise(_ id: String) -> PlanExercise? {
        exercises.first { $0.id == id }
    }
}

struct WorkoutPlan: Codable, Hashable {
    var days: [PlanDay]

    func day(_ id: String) -> PlanDay? {
        days.first { $0.id == id }
    }

    /// Days run in order and wrap around; a missed day just waits its turn.
    func nextDayID(after lastDayID: String?) -> String {
        guard let lastDayID, let index = days.firstIndex(where: { $0.id == lastDayID }) else {
            return days.first?.id ?? "A"
        }
        return days[(index + 1) % days.count].id
    }

    var exerciseNames: Set<String> {
        Set(days.flatMap { $0.exercises.map(\.name) })
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
