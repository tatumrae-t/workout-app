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
    }

    var nextDayID: String {
        plan.nextDayID(after: workouts.first { $0.dayID != nil }?.dayID)
    }

    // MARK: Workouts in progress

    func start(_ day: PlanDay) {
        let workout = ActiveWorkout(day: day, lastSets: lastSets)
        workout.onRestFinished = {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            Beep.shared.play()
        }
        workout.onRestChanged = { [weak workout] end in
            RestNotification.schedule(at: end)
            if let workout {
                RestActivityController.show(until: end, for: workout)
            }
        }
        active = workout
        Task { await RestNotification.requestPermission() }
    }

    func finishActive() {
        guard let workout = active else { return }
        workout.stopRest()
        if workout.loggedSetCount > 0 {
            add(workout.makeWorkout(source: .phone))
        }
        active = nil
    }

    func discardActive() {
        active?.stopRest()
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
