import SwiftUI

struct ActiveWorkoutView: View {
    @EnvironmentObject private var model: AppModel
    @ObservedObject var workout: ActiveWorkout
    @State private var confirmingDiscard = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if workout.isPaused {
                        pausedCard
                    } else if workout.isResting {
                        RestCard(workout: workout)
                    } else if workout.isFinished {
                        finishedCard
                    } else {
                        SetLoggerCard(workout: workout)
                    }
                }

                Section("Today") {
                    ForEach(workout.day.exercises) { exercise in
                        exerciseRow(exercise)
                    }
                }
            }
            .navigationTitle(workout.day.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard", role: .destructive) { confirmingDiscard = true }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Finish") { model.finishActive() }
                        .bold()
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        workout.isPaused ? workout.resume() : workout.pause()
                    } label: {
                        Label(workout.isPaused ? "Resume" : "Pause", systemImage: workout.isPaused ? "play.fill" : "pause.fill")
                    }
                }
            }
            .confirmationDialog("Discard this workout?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                Button("Discard workout", role: .destructive) { model.discardActive() }
            } message: {
                Text("Sets you've logged won't be saved.")
            }
        }
    }

    private var pausedCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.yellow)
            Text("Paused").font(.title3.bold())
            Text("\(Format.duration(workout.elapsed())) so far · \(workout.loggedSetCount) sets")
                .foregroundStyle(.secondary)
            Button("Resume") { workout.resume() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }

    private var finishedCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            Text("All sets done").font(.title3.bold())
            Text("\(workout.loggedSetCount) sets in \(Format.duration(workout.elapsed()))")
                .foregroundStyle(.secondary)
            Button("Finish workout") { model.finishActive() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
    }

    private func exerciseRow(_ exercise: PlanExercise) -> some View {
        let done = workout.sets(for: exercise)
        let isCurrent = workout.currentExercise?.id == exercise.id
        return HStack(alignment: .firstTextBaseline) {
            Image(systemName: done.count >= exercise.sets ? "checkmark.circle.fill" : (isCurrent ? "circle.inset.filled" : "circle"))
                .foregroundStyle(done.count >= exercise.sets ? Color.green : (isCurrent ? Color.accentColor : Color.secondary))
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.displayName)
                    .fontWeight(isCurrent ? .semibold : .regular)
                Text(done.isEmpty ? exercise.targetText : Format.sets(done))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct SetLoggerCard: View {
    @ObservedObject var workout: ActiveWorkout

    var body: some View {
        if let exercise = workout.currentExercise, let step = workout.currentStep {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.displayName).font(.title2.bold())
                    Text("Set \(step.setNumber) of \(step.totalSets) · \(exercise.repsText) reps")
                        .foregroundStyle(.secondary)
                    if let last = workout.lastTime(for: exercise), !last.isEmpty {
                        Text("Last time: \(Format.sets(last))")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if let note = workout.note {
                        Label(note, systemImage: "arrow.up.circle")
                            .font(.footnote)
                            .foregroundStyle(.green)
                    }
                }

                if exercise.usesWeight {
                    Stepper(value: $workout.weight, in: 0...500, step: 2.5) {
                        Text("\(Format.weight(workout.weight)) lb")
                            .font(.title3.monospacedDigit())
                    }
                } else if let loadNote = exercise.loadNote {
                    Text(loadNote.prefix(1).uppercased() + loadNote.dropFirst())
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Stepper(value: $workout.reps, in: 0...100) {
                    Text("\(workout.reps) reps")
                        .font(.title3.monospacedDigit())
                }

                EffortPicker(rpe: $workout.rpe)

                Button {
                    workout.logSet()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                } label: {
                    Text("Log set").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                HStack {
                    Button("Undo last") { workout.undo() }
                        .disabled(workout.index == 0)
                    Spacer()
                    Button("Skip set") { workout.skipSet() }
                    Spacer()
                    Button("Skip exercise") { workout.skipExercise() }
                }
                .buttonStyle(.borderless)
                .font(.footnote)
            }
            .padding(.vertical, 4)
        }
    }
}

struct RestCard: View {
    @ObservedObject var workout: ActiveWorkout

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int((workout.restEndsAt ?? context.date).timeIntervalSince(context.date).rounded(.up)))
            let fraction = workout.restDuration > 0 ? Double(remaining) / Double(workout.restDuration) : 0

            VStack(spacing: 14) {
                Text("Rest").font(.headline).foregroundStyle(.secondary)
                ZStack {
                    Circle().stroke(.quaternary, lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(.green, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: remaining)
                    Text(Format.clock(remaining))
                        .font(.system(size: 44, weight: .semibold, design: .rounded).monospacedDigit())
                }
                .frame(width: 170, height: 170)

                if let next = workout.currentExercise, let step = workout.currentStep {
                    Text("Next: \(next.displayName), set \(step.setNumber) · \(Format.weight(workout.weight)) lb × \(workout.reps)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                HStack(spacing: 12) {
                    Button("+15 sec") { workout.addRest(seconds: 15) }
                        .buttonStyle(.bordered)
                    Button("Skip rest") { workout.stopRest() }
                        .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical)
        }
    }
}

/// Optional RPE for the set: tap a number, tap it again to clear.
struct EffortPicker: View {
    @Binding var rpe: Double?
    @State private var showingGuide = false

    private let choices: [Double] = [6, 7, 8, 9, 10]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Effort (RPE)").font(.subheadline)
                Button {
                    showingGuide = true
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.borderless)
                Spacer()
            }
            HStack(spacing: 8) {
                ForEach(choices, id: \.self) { choice in
                    let selected = rpe == choice
                    Button {
                        rpe = selected ? nil : choice
                    } label: {
                        Text(Effort.text(choice))
                            .font(.body.monospacedDigit().bold())
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(selected ? Color.accentColor : Color.secondary)
                }
            }
            Text(rpe.flatMap(Effort.level(for:)).map { "\($0.title). \($0.detail)" } ?? "Optional. \(Effort.target)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .sheet(isPresented: $showingGuide) {
            EffortGuide()
        }
    }
}

/// What each RPE number means.
struct EffortGuide: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Effort.levels) { level in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(Effort.text(level.rpe))
                                .font(.title3.monospacedDigit().bold())
                                .frame(width: 32)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(level.title).font(.headline)
                                Text(level.detail).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text("RPE counts how many more reps you could have done with good form. \(Effort.target)")
                }
            }
            .navigationTitle("Effort (RPE)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
