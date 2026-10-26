import SwiftUI

@main
struct WorkoutApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Workout", systemImage: "dumbbell.fill") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            LiftsView()
                .tabItem { Label("Lifts", systemImage: "chart.line.uptrend.xyaxis") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .fullScreenCover(item: $model.active) { workout in
            ActiveWorkoutView(workout: workout)
                .environmentObject(model)
        }
    }
}
