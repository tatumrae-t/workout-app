import SwiftUI

struct StartView: View {
    @EnvironmentObject private var model: WatchModel

    var body: some View {
        List {
            ForEach(model.context.plan.days) { day in
                Button {
                    model.start(day)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        if day.id == model.context.nextDayID {
                            Text("UP NEXT")
                                .font(.caption2.bold())
                                .foregroundStyle(.green)
                        }
                        Text("Day \(day.id)").font(.headline)
                        Text(day.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Workouts")
    }
}

struct SummaryView: View {
    @EnvironmentObject private var model: WatchModel
    let workout: Workout

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
                Text("Nice work").font(.headline)
                Text("\(workout.setCount) sets · \(Format.duration(workout.duration))")
                    .foregroundStyle(.secondary)
                Text("Saved to Health and sent to your iPhone.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Done") { model.finished = nil }
                    .tint(.green)
            }
        }
    }
}
