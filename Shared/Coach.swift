import Foundation

struct SetSuggestion: Equatable {
    var weight: Double
    var reps: Int
    var note: String?
}

/// Picks the weight and reps to prefill for a set, following the plan's
/// progression rules.
enum Coach {
    static func suggestion(
        for exercise: PlanExercise,
        thisSession: [LoggedSet],
        lastTime: [LoggedSet]?
    ) -> SetSuggestion {
        // Later sets repeat whatever you just did.
        if let previous = thisSession.last {
            return SetSuggestion(weight: previous.weight, reps: previous.reps, note: nil)
        }

        guard let lastTime, !lastTime.isEmpty else {
            return SetSuggestion(weight: exercise.weight ?? 0, reps: exercise.repsLow, note: nil)
        }

        let top = lastTime.map(\.weight).max() ?? 0
        let hitTopOfRange = lastTime.count >= exercise.sets
            && lastTime.allSatisfy { $0.reps >= exercise.repsHigh }

        if hitTopOfRange {
            if !exercise.usesWeight {
                let note = exercise.name.contains("Pull Up")
                    ? "All sets hit \(exercise.repsHigh) last time. Try a lighter band."
                    : nil
                return SetSuggestion(weight: top, reps: exercise.repsHigh, note: note)
            }
            if exercise.isDumbbell && top >= 25 && top < 35 {
                return SetSuggestion(
                    weight: top, reps: exercise.repsHigh,
                    note: "Next dumbbell is 35, so add a rep or two first."
                )
            }
            return SetSuggestion(
                weight: top + 5, reps: exercise.repsLow,
                note: "You hit the top of the range last time, so +5 lb."
            )
        }

        let firstReps = lastTime.first?.reps ?? exercise.repsLow
        return SetSuggestion(weight: top, reps: max(firstReps, exercise.repsLow), note: nil)
    }
}
