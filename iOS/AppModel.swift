import Combine
import SwiftUI
import UserNotifications

@MainActor
final class AppModel: ObservableObject {
    let plan = DefaultPlan.plan

    /// Newest first.
    @Published private(set) var workouts: [Workout] = []
    @Published var active: ActiveWorkout?
    /// Your most recent sets for each plan exercise, keyed by Strong name.
    @Published private(set) var lastSets: [String: [LoggedSet]] = [:]

    private let connectivity = PhoneConnectivity()
    private static let file = "workouts.json"
    private static let activeFile = "active-workout.json"
    private var savingActive: AnyCancellable?

    init() {
        workouts = (Storage.load([Workout].self, from: Self.file) ?? [])
            .sorted { $0.startDate > $1.startDate }
        refreshLastSets()
        connectivity.onWorkoutReceived = { [weak self] workout in
            self?.add(workout)
        }
        connectivity.activate()
        pushToWatch()
        RestActivityController.endAll()
        if let saved = Storage.load(ActiveWorkout.Snapshot.self, from: Self.activeFile) {
            let workout = ActiveWorkout(snapshot: saved)
            attach(workout)
            workout.resumeSavedRest()
        }
    }

    var nextDayID: String {
        plan.nextDayID(after: workouts.first { $0.dayID != nil }?.dayID)
    }

    // MARK: Workouts in progress

    func start(_ day: PlanDay) {
        attach(ActiveWorkout(day: day, lastSets: lastSets))
        Task { await RestNotification.requestPermission() }
    }

    /// Wires up alerts and saving, so the workout survives the app closing.
    private func attach(_ workout: ActiveWorkout) {
        workout.onRestFinished = {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Beep.shared.play()
        }
        workout.onRestChanged = { [weak workout] end in
            RestNotification.schedule(at: end)
            Beep.shared.holdDuringRest(end != nil)
            if let workout {
                RestActivityController.show(until: end, for: workout)
            }
        }
        active = workout
        Storage.save(workout.snapshot, to: Self.activeFile)
        savingActive = workout.objectWillChange
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak workout] _ in
                MainActor.assumeIsolated {
                    guard let workout else { return }
                    Storage.save(workout.snapshot, to: Self.activeFile)
                }
            }
    }

    private func clearSavedActive() {
        savingActive = nil
        Storage.delete(Self.activeFile)
    }

    func finishActive() {
        guard let workout = active else { return }
        workout.stopRest()
        if workout.loggedSetCount > 0 {
            add(workout.makeWorkout(source: .phone))
        }
        clearSavedActive()
        active = nil
    }

    func discardActive() {
        active?.stopRest()
        clearSavedActive()
        active = nil
    }

    // MARK: History

    func add(_ workout: Workout) {
        guard !workouts.contains(where: { $0.id == workout.id }) else { return }
        workouts.append(workout)
        didChangeWorkouts()
    }

    func delete(_ workout: Workout) {
        workouts.removeAll { $0.id == workout.id }
        didChangeWorkouts()
    }

    /// Saves a corrected set; "last time" and suggestions follow the fix.
    func updateSet(_ set: LoggedSet, in workoutID: UUID) {
        guard let w = workouts.firstIndex(where: { $0.id == workoutID }) else { return }
        for e in workouts[w].exercises.indices {
            if let s = workouts[w].exercises[e].sets.firstIndex(where: { $0.id == set.id }) {
                workouts[w].exercises[e].sets[s] = set
                didChangeWorkouts()
                return
            }
        }
    }

    func deleteSet(id: UUID, in workoutID: UUID) {
        guard let w = workouts.firstIndex(where: { $0.id == workoutID }) else { return }
        for e in workouts[w].exercises.indices {
            workouts[w].exercises[e].sets.removeAll { $0.id == id }
        }
        workouts[w].exercises.removeAll { $0.sets.isEmpty }
        didChangeWorkouts()
    }

    func usesWeight(_ exerciseName: String) -> Bool {
        plan.days.lazy.flatMap(\.exercises).first { $0.name == exerciseName }?.usesWeight ?? true
    }

    /// Returns how many new workouts were added. Workouts already imported are skipped.
    func importStrong(from url: URL) throws -> (added: Int, skipped: Int) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let text = try String(contentsOf: url, encoding: .utf8)
        let imported = try StrongImport.workouts(fromCSV: text)

        let existing = Set(workouts.filter { $0.source == .strong }.map(\.startDate))
        let fresh = imported.filter { !existing.contains($0.startDate) }
        workouts.append(contentsOf: fresh)
        didChangeWorkouts()
        return (fresh.count, imported.count - fresh.count)
    }

    /// Adds workouts from a backup file. Ones already here are skipped.
    func restoreBackup(from url: URL) throws -> (added: Int, skipped: Int) {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        let restored = try Backup.workouts(from: Data(contentsOf: url))
        let existing = Set(workouts.map(\.id))
        let fresh = restored.filter { !existing.contains($0.id) }
        workouts.append(contentsOf: fresh)
        didChangeWorkouts()
        return (fresh.count, restored.count - fresh.count)
    }

    func backUpNow() {
        AutoBackup.save(workouts)
    }

    var strongWorkoutCount: Int {
        workouts.filter { $0.source == .strong }.count
    }

    func deleteStrongHistory() {
        workouts.removeAll { $0.source == .strong }
        didChangeWorkouts()
    }

    func pushToWatch() {
        connectivity.send(WatchContext(
            plan: plan,
            nextDayID: nextDayID,
            lastSets: lastSets,
            updatedAt: Date()
        ))
    }

    private func didChangeWorkouts() {
        workouts.sort { $0.startDate > $1.startDate }
        Storage.save(workouts, to: Self.file)
        AutoBackup.save(workouts)
        refreshLastSets()
        pushToWatch()
    }

    private func refreshLastSets() {
        let names = plan.exerciseNames
        var result: [String: [LoggedSet]] = [:]
        for workout in workouts {
            for exercise in workout.exercises where names.contains(exercise.name) && result[exercise.name] == nil {
                result[exercise.name] = exercise.sets
            }
            if result.count == names.count { break }
        }
        lastSets = result
    }
}

/// Buzzes you when rest is up, even if the app is in the background.
enum RestNotification {
    private static let id = "rest-timer"

    static func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound])
    }

    static func schedule(at end: Date?) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard let end, end.timeIntervalSinceNow > 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest's up"
        content.body = "Time for your next set."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: end.timeIntervalSinceNow, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
