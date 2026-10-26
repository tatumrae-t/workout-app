import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var model: AppModel

    /// Next day first.
    private var days: [PlanDay] {
        let next = model.nextDayID
        return model.plan.days.filter { $0.id == next } + model.plan.days.filter { $0.id != next }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(days) { day in
                    Section {
                        ForEach(day.exercises) { exercise in
                            PlanExerciseRow(exercise: exercise, lastTime: model.lastSets[exercise.name])
                        }
                        Button {
                            model.start(day)
                        } label: {
                            Label("Start on iPhone", systemImage: "play.fill")
                                .font(.headline)
                        }
                    } header: {
                        HStack {
                            Text(day.title)
                            if day.id == model.nextDayID {
                                Text("UP NEXT")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.green.opacity(0.2), in: Capsule())
                                    .foregroundStyle(.green)
                            }
                        }
                    } footer: {
                        Text(day.warmupNote)
                    }
                }

                Section {
                    Label("Start from your Watch to track heart rate and close your rings. It shows up here when you finish.",
                          systemImage: "applewatch")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Workouts")
        }
    }
}

struct PlanExerciseRow: View {
    let exercise: PlanExercise
    let lastTime: [LoggedSet]?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(exercise.displayName)
                if exercise.supersetGroup != nil {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if exercise.isOptional {
                    Text("optional").font(.caption).foregroundStyle(.secondary)
                }
            }
            Text(targetLine)
                .font(.caption)
                .foregroundStyle(.secondary)
            if let lastTime, !lastTime.isEmpty {
                Text("Last: \(Format.sets(lastTime))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var targetLine: String {
        let load = exercise.weight.map { "\(Format.weight($0)) lb" } ?? exercise.loadNote ?? ""
        return load.isEmpty ? exercise.targetText : "\(exercise.targetText) · \(load)"
    }
}
