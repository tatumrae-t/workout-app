import Foundation
import WatchConnectivity

/// Receives the plan from the iPhone and sends finished workouts back.
/// Workouts are queued by the system, so they arrive even if the iPhone is
/// out of range when you finish.
final class WatchConnectivityManager: NSObject, WCSessionDelegate {
    /// Called on the main thread.
    var onContextReceived: ((WatchContext) -> Void)?
    private var pending: [Workout] = []

    func activate() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    func send(_ workout: Workout) {
        guard WCSession.default.activationState == .activated else {
            pending.append(workout)
            return
        }
        guard let data = try? JSONEncoder().encode(workout) else { return }
        WCSession.default.transferUserInfo([SyncKey.workout: data])
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        let context = session.receivedApplicationContext
        DispatchQueue.main.async {
            self.handle(context)
            let queued = self.pending
            self.pending = []
            queued.forEach(self.send)
        }
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        DispatchQueue.main.async {
            self.handle(applicationContext)
        }
    }

    private func handle(_ applicationContext: [String: Any]) {
        guard let data = applicationContext[SyncKey.context] as? Data,
              let context = try? JSONDecoder().decode(WatchContext.self, from: data) else { return }
        onContextReceived?(context)
    }
}
