import Combine
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
    private static let activeFile = "active-workout.json"
    private var savingActive: AnyCancellable?

    init() {
        context = Storage.load(WatchContext.self, from: Self.file) ?? .initial
        connectivity.onContextReceived = { [weak self] context in
            self?.receive(context)
        }
        connectivity.activate()
        if let saved = Storage.load(ActiveWorkout.Snapshot.self, from: Self.activeFile) {
            let workout = ActiveWorkout(snapshot: saved)
            attach(workout)
            workout.resumeSavedRest()
            // Pick the Health session back up so time and calories carry on.
            Task {
                await health.recover()
                if workout.isPaused { health.pause() }
            }
        }
    }

    func start(_ day: PlanDay) {
        attach(ActiveWorkout(day: day, lastSets: context.lastSets))
        Task {
            await health.requestAuthorization()
            await health.start()
        }
    }

    /// Wires up alerts and saving, so the workout survives the app closing.
    private func attach(_ workout: ActiveWorkout) {
        workout.onRestFinished = {
            WKInterfaceDevice.current().play(.notification)
            Beep.shared.play()
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
        clearSavedActive()
        active = nil
        WKInterfaceDevice.current().play(.success)
    }

    func togglePause() {
        guard let workout = active else { return }
        if workout.isPaused {
            workout.resume()
            health.resume()
        } else {
            workout.pause()
            health.pause()
        }
        WKInterfaceDevice.current().play(workout.isPaused ? .stop : .start)
    }

    func discard() {
        active?.stopRest()
        health.discard()
        clearSavedActive()
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
