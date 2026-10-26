import Foundation

/// RPE (rate of perceived exertion): how hard a set was, counted by how many
/// more reps you could have done with good form.
enum Effort {
    struct Level: Identifiable {
        let rpe: Double
        let title: String
        let detail: String

        var id: Double { rpe }
    }

    static let levels: [Level] = [
        Level(rpe: 10, title: "0 reps left", detail: "All-out. You couldn't have done another rep, or you failed the last one."),
        Level(rpe: 9, title: "1 rep left", detail: "Very hard. Maybe one more, and it would have been a grind."),
        Level(rpe: 8, title: "2 reps left", detail: "Hard, but the last rep still moved well."),
        Level(rpe: 7, title: "3 reps left", detail: "Solid working set. Speed only slowed near the end."),
        Level(rpe: 6, title: "4+ reps left", detail: "Moderate. The weight moved fast the whole set."),
        Level(rpe: 5, title: "Easy", detail: "Warm-up effort."),
    ]

    /// Most of your sets aim to stop 2 to 3 reps short.
    static let target = "Aim for 7–8 on most sets."

    static func level(for rpe: Double) -> Level? {
        levels.first { $0.rpe == rpe }
    }

    /// "8", or "8.5" for half points imported from Strong.
    static func text(_ rpe: Double) -> String {
        rpe.rounded() == rpe ? "\(Int(rpe))" : String(format: "%.1f", rpe)
    }
}
