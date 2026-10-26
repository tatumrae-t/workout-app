import Combine
import Foundation

/// One set to do, in the order you'll do it. Supersets alternate sets.
struct SessionStep: Identifiable, Hashable {
    let id: Int
    let exerciseID: String
    let setNumber: Int
    let totalSets: Int
    /// Rest after this set. 0 between the halves of a superset.
    let restAfter: Int

    static func build(for day: PlanDay) -> [SessionStep] {
        var groups: [[PlanExercise]] = []
        for exercise in day.exercises {
            if let group = exercise.supersetGroup, groups.last?.first?.supersetGroup == group {
                groups[groups.count - 1].append(exercise)
            } else {
                groups.append([exercise])
            }
        }

        var steps: [SessionStep] = []
        for group in groups {
            let rounds = group.map(\.sets).max() ?? 0
            for round in 0..<rounds {
                let inRound = group.filter { round < $0.sets }
                for (position, exercise) in inRound.enumerated() {
                    let isLast = position == inRound.count - 1
                    steps.append(SessionStep(
                        id: steps.count,
                        exerciseID: exercise.id,
                        setNumber: round + 1,
                        totalSets: exercise.sets,
                        restAfter: isLast ? exercise.restSeconds : 0
                    ))
                }
            }
        }
        return steps
    }
}

/// A workout in progress, shared by the iPhone and Watch apps.
@MainActor
final class ActiveWorkout: ObservableObject, Identifiable {
    let id = UUID()
    let day: PlanDay
    let startDate: Date
    /// Sets from the last time you did each exercise, keyed by Strong name.
    let lastSets: [String: [LoggedSet]]

    @Published private(set) var steps: [SessionStep]
    @Published private(set) var index = 0
    /// Logged sets keyed by PlanExercise.id.
    @Published private(set) var logged: [String: [LoggedSet]] = [:]
    @Published private(set) var restEndsAt: Date?
    @Published private(set) var restDuration = 0
    @Published private(set) var note: String?
    @Published private(set) var pausedAt: Date?
    /// Time spent in earlier pauses; the current one is added on resume.
    @Published private(set) var pausedTime: TimeInterval = 0

    /// The values shown in the set logger, prefilled from the suggestion.
    @Published var weight: Double = 0
    @Published var reps: Int = 0
    /// Effort for the set being logged; optional, so it starts blank each set.
    @Published var rpe: Double?

    /// Called when a rest timer runs out (for a beep and a haptic).
    var onRestFinished: (() -> Void)?
    /// Called with the new end time whenever rest starts, changes or stops.
    var onRestChanged: ((Date?) -> Void)?

    private var stepSet: [Int: UUID] = [:]
    private var restTask: Task<Void, Never>?
    /// Rest that was left when you paused, picked back up on resume.
    private var pausedRest: TimeInterval?

    init(day: PlanDay, lastSets: [String: [LoggedSet]], startDate: Date = Date()) {
        self.day = day
        self.lastSets = lastSets
        self.startDate = startDate
        self.steps = SessionStep.build(for: day)
        loadSuggestion()
    }

    var isFinished: Bool { index >= steps.count }
    var currentStep: SessionStep? { steps[safe: index] }
    var currentExercise: PlanExercise? { currentStep.flatMap { day.exercise($0.exerciseID) } }
    var loggedSetCount: Int { logged.values.reduce(0) { $0 + $1.count } }
    var progress: Double { steps.isEmpty ? 1 : Double(index) / Double(steps.count) }
    var isResting: Bool { restEndsAt != nil }
    var isPaused: Bool { pausedAt != nil }

    /// Workout time so far, not counting pauses.
    func elapsed(at date: Date = Date()) -> TimeInterval {
        (pausedAt ?? date).timeIntervalSince(startDate) - pausedTime
    }

    /// When the workout would have started with no pauses, for running clocks.
    var clockStart: Date { startDate.addingTimeInterval(pausedTime) }

    func lastTime(for exercise: PlanExercise) -> [LoggedSet]? {
        lastSets[exercise.name]
    }

    func sets(for exercise: PlanExercise) -> [LoggedSet] {
        logged[exercise.id] ?? []
    }

    // MARK: Logging

    func logSet() {
        guard let step = currentStep else { return }
        let set = LoggedSet(weight: weight, reps: reps, rpe: rpe)
        logged[step.exerciseID, default: []].append(set)
        stepSet[step.id] = set.id
        index += 1
        loadSuggestion()
        if step.restAfter > 0 && !isFinished {
            startRest(seconds: step.restAfter)
        } else {
            stopRest()
        }
    }

    func skipSet() {
        guard currentStep != nil else { return }
        stopRest()
        index += 1
        loadSuggestion()
    }

    /// Drops the rest of the current exercise, e.g. an optional one.
    func skipExercise() {
        guard let current = currentStep else { return }
        stopRest()
        steps.removeAll { $0.exerciseID == current.exerciseID && $0.id >= current.id && stepSet[$0.id] == nil }
        // Without its partner, the other half of a superset needs its own rest.
        if let group = day.exercise(current.exerciseID)?.supersetGroup {
            steps = steps.map { step in
                guard step.id > current.id, step.restAfter == 0,
                      let exercise = day.exercise(step.exerciseID),
                      exercise.supersetGroup == group else { return step }
                return SessionStep(
                    id: step.id, exerciseID: step.exerciseID, setNumber: step.setNumber,
                    totalSets: step.totalSets, restAfter: exercise.restSeconds
                )
            }
        }
        loadSuggestion()
    }

    /// Steps back one set. If it was logged, the set is removed so you can redo it.
    func undo() {
        guard index > 0 else { return }
        stopRest()
        index -= 1
        let step = steps[index]
        if let setID = stepSet.removeValue(forKey: step.id),
           let removed = logged[step.exerciseID]?.first(where: { $0.id == setID }) {
            logged[step.exerciseID]?.removeAll { $0.id == setID }
            loadSuggestion()
            weight = removed.weight
            reps = removed.reps
            rpe = removed.rpe
        } else {
            loadSuggestion()
        }
    }

    // MARK: Fixing logged sets

    /// The set you logged most recently, for a quick fix.
    var lastLogged: (exercise: PlanExercise, set: LoggedSet)? {
        var latest: (exercise: PlanExercise, set: LoggedSet)?
        for (key, sets) in logged {
            guard let exercise = day.exercise(key), let set = sets.last else { continue }
            if latest == nil || set.completedAt > latest!.set.completedAt {
                latest = (exercise, set)
            }
        }
        return latest
    }

    /// Replaces a logged set with a corrected copy (same id).
    func updateSet(_ set: LoggedSet) {
        for (key, sets) in logged {
            guard let i = sets.firstIndex(where: { $0.id == set.id }) else { continue }
            logged[key]?[i] = set
            // The next set's prefill copies the last one, so keep it in step.
            if key == currentExercise?.id && i == sets.count - 1 {
                weight = set.weight
                reps = set.reps
            }
            return
        }
    }

    /// Removes a logged set. Its spot in the session counts as skipped.
    func deleteSet(id: UUID) {
        for key in logged.keys {
            logged[key]?.removeAll { $0.id == id }
        }
        stepSet = stepSet.filter { $0.value != id }
    }

    func adjustWeight(by delta: Double) {
        weight = max(0, weight + delta)
    }

    func adjustReps(by delta: Int) {
        reps = max(0, reps + delta)
    }

    private func loadSuggestion() {
        rpe = nil
        guard let exercise = currentExercise else {
            note = nil
            return
        }
        let suggestion = Coach.suggestion(
            for: exercise,
            thisSession: sets(for: exercise),
            lastTime: lastTime(for: exercise)
        )
        weight = suggestion.weight
        reps = suggestion.reps
        note = suggestion.note
    }

    // MARK: Rest timer

    func startRest(seconds: Int) {
        restDuration = seconds
        scheduleRestEnd(at: Date().addingTimeInterval(TimeInterval(seconds)))
    }

    func addRest(seconds: Int) {
        guard let end = restEndsAt else { return }
        restDuration += seconds
        scheduleRestEnd(at: end.addingTimeInterval(TimeInterval(seconds)))
    }

    func stopRest() {
        restTask?.cancel()
        restTask = nil
        if restEndsAt != nil {
            restEndsAt = nil
            onRestChanged?(nil)
        }
    }

    private func scheduleRestEnd(at end: Date) {
        restTask?.cancel()
        restEndsAt = end
        onRestChanged?(end)
        restTask = Task { [weak self] in
            let wait = max(0, end.timeIntervalSinceNow)
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
            guard !Task.isCancelled, let self else { return }
            self.restEndsAt = nil
            self.restTask = nil
            self.onRestChanged?(nil)
            // If the app was suspended past the end, it's too late to alert.
            if Date().timeIntervalSince(end) < 3 {
                self.onRestFinished?()
            }
        }
    }

    // MARK: Pausing

    func pause() {
        guard pausedAt == nil else { return }
        pausedAt = Date()
        if let end = restEndsAt {
            pausedRest = max(0, end.timeIntervalSinceNow)
        }
        stopRest()
    }

    func resume() {
        guard let pausedAt else { return }
        pausedTime += Date().timeIntervalSince(pausedAt)
        self.pausedAt = nil
        if let rest = pausedRest, rest >= 1 {
            scheduleRestEnd(at: Date().addingTimeInterval(rest))
        }
        pausedRest = nil
    }

    // MARK: Finishing

    func makeWorkout(source: WorkoutSource, endDate: Date = Date()) -> Workout {
        let exercises = day.exercises.compactMap { exercise -> LoggedExercise? in
            let done = self.sets(for: exercise)
            return done.isEmpty ? nil : LoggedExercise(name: exercise.name, sets: done)
        }
        return Workout(
            name: day.title,
            dayID: day.id,
            startDate: startDate,
            endDate: endDate,
            source: source,
            exercises: exercises,
            pausedTime: pausedTime + (pausedAt.map { endDate.timeIntervalSince($0) } ?? 0)
        )
    }
}
