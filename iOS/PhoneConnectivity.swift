import Foundation
import WatchConnectivity

/// Sends the plan to the Watch and receives finished workouts from it.
final class PhoneConnectivity: NSObject, WCSessionDelegate {
    /// Called on the main thread.
    var onWorkoutReceived: ((Workout) -> Void)?
    private var pendingContext: WatchContext?

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ context: WatchContext) {
        pendingContext = context
        guard WCSession.isSupported(),
              WCSession.default.activationState == .activated,
              WCSession.default.isWatchAppInstalled,
              let data = try? JSONEncoder().encode(context) else { return }
        try? WCSession.default.updateApplicationContext([SyncKey.context: data])
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async {
            if let context = self.pendingContext { self.send(context) }
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        // Happens when you switch watches; reconnect to the new one.
        session.activate()
    }

    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async {
            if let context = self.pendingContext { self.send(context) }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let data = userInfo[SyncKey.workout] as? Data,
              let workout = try? JSONDecoder().decode(Workout.self, from: data) else { return }
        DispatchQueue.main.async {
            self.onWorkoutReceived?(workout)
        }
    }
}
