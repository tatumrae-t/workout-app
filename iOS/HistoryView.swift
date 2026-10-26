import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationStack {
            Group {
                if model.workouts.isEmpty {
                    ContentUnavailableView(
                        "No workouts yet",
                        systemImage: "clock",
                        description: Text("Finish a workout, or import your Strong history in Settings.")
                    )
                } else {
                    List {
                        ForEach(model.workouts) { workout in
                            NavigationLink(value: workout) {
                                WorkoutRow(workout: workout)
                            }
                        }
                        .onDelete { offsets in
                            offsets.map { model.workouts[$0] }.forEach(model.delete)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: Workout.self) { workout in
                WorkoutDetailView(workout: workout)
            }
        }
    }
}

struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.name).lineLimit(1)
                Text("\(workout.startDate.formatted(date: .abbreviated, time: .omitted)) · \(workout.setCount) sets · \(Format.duration(workout.duration))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var icon: String {
        switch workout.source {
        case .watch: "applewatch"
        case .phone: "iphone"
        case .strong: "square.and.arrow.down"
        }
    }
}

struct WorkoutDetailView: View {
    @EnvironmentObject private var model: AppModel
    let workoutID: UUID
    @State private var editing: SetEditTarget?

    init(workout: Workout) {
        workoutID = workout.id
    }

    var body: some View {
        if let workout = model.workouts.first(where: { $0.id == workoutID }) {
            details(workout)
        } else {
            ContentUnavailableView("Workout deleted", systemImage: "trash")
        }
    }

    private func details(_ workout: Workout) -> some View {
        List {
            Section {
                LabeledContent("Date", value: workout.startDate.formatted(date: .long, time: .shortened))
                LabeledContent("Duration", value: Format.duration(workout.duration))
                LabeledContent("Sets", value: "\(workout.setCount)")
            }
            ForEach(workout.exercises) { exercise in
                Section(exercise.name) {
                    ForEach(Array(exercise.sets.enumerated()), id: \.element.id) { number, set in
                        Button {
                            editing = SetEditTarget(
                                title: "\(exercise.name), set \(number + 1)",
                                set: set,
                                usesWeight: model.usesWeight(exercise.name)
                            )
                        } label: {
                            HStack {
                                Text("Set \(number + 1)").foregroundStyle(.secondary)
                                Spacer()
                                Text(Format.set(set)).monospacedDigit().foregroundStyle(.primary)
                            }
                        }
                        .swipeActions {
                            Button("Delete", role: .destructive) {
                                model.deleteSet(id: set.id, in: workout.id)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { target in
            SetEditor(title: target.title, set: target.set, usesWeight: target.usesWeight) { fixed in
                model.updateSet(fixed, in: workout.id)
            } onDelete: {
                model.deleteSet(id: target.set.id, in: workout.id)
            }
        }
    }
}
