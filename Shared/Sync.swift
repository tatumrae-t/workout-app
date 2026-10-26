import Foundation

/// What the iPhone sends the Watch: the plan, which day is next, and your
/// last sets for each exercise so the Watch can prefill weights.
struct WatchContext: Codable {
    var plan: WorkoutPlan
    var nextDayID: String
    var lastSets: [String: [LoggedSet]]
    var updatedAt: Date

    static let initial = WatchContext(
        plan: DefaultPlan.plan,
        nextDayID: DefaultPlan.plan.days.first?.id ?? "A",
        lastSets: [:],
        updatedAt: .distantPast
    )

    /// Folds a finished workout in, so the next one prefills correctly even
    /// before the iPhone has seen it.
    mutating func record(_ workout: Workout) {
        for exercise in workout.exercises {
            lastSets[exercise.name] = exercise.sets
        }
        if let dayID = workout.dayID {
            nextDayID = plan.nextDayID(after: dayID)
        }
        updatedAt = Date()
    }
}

enum SyncKey {
    static let context = "context"
    static let workout = "workout"
}

enum Storage {
    private static var directory: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func load<T: Decodable>(_ type: T.Type, from file: String) -> T? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(file)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    static func save<T: Encodable>(_ value: T, to file: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: directory.appendingPathComponent(file), options: .atomic)
    }
}
