import SwiftUI
import WatchKit

/// Swipe left for controls, right for heart rate.
struct SessionView: View {
    @EnvironmentObject private var model: WatchModel
    @ObservedObject var workout: ActiveWorkout
    @State private var page = 1

    var body: some View {
        TabView(selection: $page) {
            ControlsView(workout: workout)
                .tag(0)
            Group {
                if workout.isResting {
                    RestView(workout: workout)
                } else if workout.isFinished {
                    FinishView(workout: workout)
                } else {
                    SetLoggerView(workout: workout)
                }
            }
            .tag(1)
            MetricsView(health: model.health, startDate: workout.startDate, workout: workout)
                .tag(2)
        }
        .tabViewStyle(.page)
        .navigationBarBackButtonHidden()
    }
}

struct SetLoggerView: View {
    @ObservedObject var workout: ActiveWorkout

    var body: some View {
        if let exercise = workout.currentExercise, let step = workout.currentStep {
            ScrollView {
                VStack(spacing: 6) {
                    Text(exercise.displayName)
                        .font(.headline)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text("Set \(step.setNumber)/\(step.totalSets) · \(exercise.repsText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if exercise.usesWeight {
                        WeightControl(workout: workout)
                    } else if let loadNote = exercise.loadNote {
                        Text(loadNote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Button { workout.adjustReps(by: -1) } label: { Image(systemName: "minus") }
                        Text("\(workout.reps)")
                            .font(.title2.monospacedDigit().bold())
                            .frame(minWidth: 40)
                        Button { workout.adjustReps(by: 1) } label: { Image(systemName: "plus") }
                    }
                    .buttonStyle(.bordered)
                    Text("reps").font(.caption2).foregroundStyle(.secondary)

                    Button {
                        workout.logSet()
                        WKInterfaceDevice.current().play(.click)
                    } label: {
                        Text("Done").bold().frame(maxWidth: .infinity)
                    }
                    .tint(.green)

                    if let note = workout.note {
                        Text(note)
                            .font(.caption2)
                            .foregroundStyle(.green)
                            .multilineTextAlignment(.center)
                    }
                    if let last = workout.lastTime(for: exercise), !last.isEmpty {
                        Text("Last: \(Format.sets(last))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
    }
}

/// Turn the Digital Crown to change the weight.
struct WeightControl: View {
    @ObservedObject var workout: ActiveWorkout
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text("\(Format.weight(workout.weight)) lb")
                .font(.title2.monospacedDigit().bold())
                .padding(.horizontal, 12)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(focused ? Color.green : Color.gray.opacity(0.4), lineWidth: 1.5)
                )
                .focusable()
                .focused($focused)
                .digitalCrownRotation(
                    $workout.weight,
                    from: 0,
                    through: 500,
                    by: 2.5,
                    sensitivity: .low,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )
            Text(focused ? "turn crown" : "tap, then turn crown")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
    }
}

struct RestView: View {
    @ObservedObject var workout: ActiveWorkout

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = max(0, Int((workout.restEndsAt ?? context.date).timeIntervalSince(context.date).rounded(.up)))
            let fraction = workout.restDuration > 0 ? Double(remaining) / Double(workout.restDuration) : 0

            VStack(spacing: 6) {
                ZStack {
                    Circle().stroke(Color.gray.opacity(0.3), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: fraction)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("REST").font(.caption2).foregroundStyle(.secondary)
                        Text(Format.clock(remaining))
                            .font(.title.monospacedDigit().bold())
                    }
                }
                .frame(width: 100, height: 100)

                if let next = workout.currentExercise {
                    Text("Next: \(next.displayName)")
                        .font(.caption2)
                        .lineLimit(1)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("+15") { workout.addRest(seconds: 15) }
                    Button("Skip") { workout.stopRest() }
                        .tint(.green)
                }
            }
        }
    }
}

struct FinishView: View {
    @EnvironmentObject private var model: WatchModel
    @ObservedObject var workout: ActiveWorkout

    var body: some View {
        VStack(spacing: 8) {
            Text("All sets done").font(.headline)
            Text("\(workout.loggedSetCount) sets")
                .foregroundStyle(.secondary)
            Button {
                Task { await model.finish() }
            } label: {
                Text("Finish").bold().frame(maxWidth: .infinity)
            }
            .tint(.green)
        }
    }
}

struct ControlsView: View {
    @EnvironmentObject private var model: WatchModel
    @ObservedObject var workout: ActiveWorkout
    @State private var confirmingDiscard = false

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Button {
                    Task { await model.finish() }
                } label: {
                    Label("Finish", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                }
                .tint(.green)

                Button {
                    workout.undo()
                } label: {
                    Label("Undo set", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .disabled(workout.index == 0)

                Button {
                    workout.skipSet()
                } label: {
                    Label("Skip set", systemImage: "forward")
                        .frame(maxWidth: .infinity)
                }
                .disabled(workout.isFinished)

                Button {
                    workout.skipExercise()
                } label: {
                    Label("Skip exercise", systemImage: "forward.end")
                        .frame(maxWidth: .infinity)
                }
                .disabled(workout.isFinished)

                Button(role: .destructive) {
                    confirmingDiscard = true
                } label: {
                    Label("Discard", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .confirmationDialog("Discard this workout?", isPresented: $confirmingDiscard) {
            Button("Discard", role: .destructive) { model.discard() }
        }
    }
}

struct MetricsView: View {
    @ObservedObject var health: HealthWorkoutManager
    let startDate: Date
    @ObservedObject var workout: ActiveWorkout

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(timerInterval: startDate...Date.distantFuture, countsDown: false)
                .font(.title2.monospacedDigit().bold())
                .foregroundStyle(.yellow)
            Label(health.heartRate > 0 ? "\(Int(health.heartRate)) BPM" : "-- BPM", systemImage: "heart.fill")
                .foregroundStyle(.red)
            Label("\(Int(health.activeCalories)) cal", systemImage: "flame.fill")
                .foregroundStyle(.orange)
            Label("\(workout.loggedSetCount) sets", systemImage: "dumbbell.fill")
                .foregroundStyle(.green)
            ProgressView(value: workout.progress)
                .tint(.green)
        }
        .font(.body.monospacedDigit())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
}
