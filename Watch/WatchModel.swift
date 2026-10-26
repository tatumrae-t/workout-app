import SwiftUI
import WatchKit

@MainActor
final class WatchModel: ObservableObject {
    @Published private(set) var context: WatchContext
    @Published private(set) var active: ActiveWorkout?
    /// The workout just finished, shown on the summary screen.
    @Published var finished: Workout?

    let health = HealthWorkoutManager()
    private let connectivity = WatchConnectivityManager()
    private static let file = "context.json"

    init() {
        context = Storage.load(WatchContext.self, from: Self.file) ?? .initial
        connectivity.onContextReceived = { [weak self] context in
            self?.receive(context)
        }
        connectivity.activate()
    }

    func start(_ day: PlanDay) {
        let workout = ActiveWorkout(day: day, lastSets: context.lastSets)
        workout.onRestFinished = {
            WKInterfaceDevice.current().play(.notification)
            Beep.shared.play()
        }
        active = workout
        Task {
            await health.requestAuthorization()
            await health.start()
        }
    }

    func finish() async {
        guard let workout = active else { return }
        workout.stopRest()
        await health.finish()
        if workout.loggedSetCount > 0 {
            let result = workout.makeWorkout(source: .watch)
            connectivity.send(result)
            context.record(result)
            Storage.save(context, to: Self.file)
            finished = result
        }
        active = nil
        WKInterfaceDevice.current().play(.success)
    }

    func discard() {
        active?.stopRest()
        health.discard()
        active = nil
    }

    private func receive(_ incoming: WatchContext) {
        // A workout finished on the Watch is newer than the iPhone's copy
        // until the iPhone has caught up.
        guard incoming.updatedAt >= context.updatedAt else { return }
        context = incoming
        Storage.save(context, to: Self.file)
    }
}
