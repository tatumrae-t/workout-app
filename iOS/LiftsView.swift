import SwiftUI
import Charts

/// Your best set each time you did an exercise.
struct LiftSession: Identifiable {
    let date: Date
    let best: LoggedSet
    var id: Date { date }
}

struct Lift: Identifiable {
    let name: String
    /// Oldest first.
    let sessions: [LiftSession]
    var id: String { name }

    var best: LoggedSet? {
        sessions.map(\.best).max { ($0.weight, $0.reps) < ($1.weight, $1.reps) }
    }
    var lastDate: Date { sessions.last?.date ?? .distantPast }
}

struct LiftsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var search = ""

    private var lifts: [Lift] {
        var byName: [String: [LiftSession]] = [:]
        for workout in model.workouts {
            for exercise in workout.exercises {
                guard let best = exercise.bestSet else { continue }
                byName[exercise.name, default: []].append(LiftSession(date: workout.startDate, best: best))
            }
        }
        return byName
            .map { Lift(name: $0.key, sessions: $0.value.sorted { $0.date < $1.date }) }
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search) }
            .sorted { $0.lastDate > $1.lastDate }
    }

    var body: some View {
        NavigationStack {
            List(lifts) { lift in
                NavigationLink {
                    LiftDetailView(lift: lift)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(lift.name)
                        HStack {
                            if let best = lift.best { Text("Best \(Format.set(best))") }
                            Text("· \(lift.sessions.count) sessions · last \(lift.lastDate.formatted(.dateTime.month(.abbreviated).year()))")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }
            }
            .overlay {
                if model.workouts.isEmpty {
                    ContentUnavailableView("No lifts yet", systemImage: "chart.line.uptrend.xyaxis")
                }
            }
            .searchable(text: $search)
            .navigationTitle("Lifts")
        }
    }
}

struct LiftDetailView: View {
    let lift: Lift

    private var weighted: Bool { lift.sessions.contains { $0.best.weight > 0 } }

    var body: some View {
        List {
            if lift.sessions.count > 1 {
                Section(weighted ? "Heaviest set (lb)" : "Most reps") {
                    Chart(lift.sessions) { session in
                        LineMark(
                            x: .value("Date", session.date),
                            y: .value("Value", weighted ? session.best.weight : Double(session.best.reps))
                        )
                        PointMark(
                            x: .value("Date", session.date),
                            y: .value("Value", weighted ? session.best.weight : Double(session.best.reps))
                        )
                    }
                    .frame(height: 200)
                    .padding(.vertical, 8)
                }
            }
            Section("Sessions") {
                ForEach(Array(lift.sessions.reversed())) { session in
                    HStack {
                        Text(session.date.formatted(date: .abbreviated, time: .omitted))
                        Spacer()
                        Text(Format.set(session.best)).monospacedDigit()
                    }
                }
            }
        }
        .navigationTitle(lift.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
