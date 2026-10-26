import SwiftUI

@main
struct WorkoutWatchApp: App {
    @StateObject private var model = WatchModel()

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                WatchRootView()
            }
            .environmentObject(model)
        }
    }
}

struct WatchRootView: View {
    @EnvironmentObject private var model: WatchModel

    var body: some View {
        if let workout = model.active {
            SessionView(workout: workout)
        } else if let finished = model.finished {
            SummaryView(workout: finished)
        } else {
            StartView()
        }
    }
}
