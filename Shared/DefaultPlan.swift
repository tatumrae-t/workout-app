import Foundation

/// The 2-day plan from "Workout plan from Strong history".
/// Week 1 loads start about 15% under the old bests.
enum DefaultPlan {
    static let warmup = "Posture warm-up first (about 5 min): foam roller thoracic extension 1×8 and wall slides 1×10. The band work below is logged."

    static let plan = WorkoutPlan(days: [
        PlanDay(
            id: "A",
            name: "Shoulders, back & arms",
            warmupNote: warmup,
            exercises: [
                PlanExercise(id: "a-pullapart", name: "Band Pull Apart", displayName: "Band pull-apart",
                             sets: 2, repsLow: 15, repsHigh: 15, weight: nil, loadNote: "light band", restSeconds: 30),
                PlanExercise(id: "a-extrot", name: "External Rotation (Band)", displayName: "Band external rotation",
                             sets: 2, repsLow: 12, repsHigh: 12, weight: nil, loadNote: "light band", restSeconds: 30, perSide: true),
                PlanExercise(id: "a-ohp", name: "Overhead Press (Dumbbell)", displayName: "DB shoulder press",
                             sets: 3, repsLow: 8, repsHigh: 10, weight: 15, restSeconds: 90),
                PlanExercise(id: "a-pullup", name: "Pull Up (Band)", displayName: "Band-assisted pull-up",
                             sets: 3, repsLow: 5, repsHigh: 6, weight: nil, loadNote: "heaviest band you need", restSeconds: 90),
                PlanExercise(id: "a-row", name: "Incline Row (Dumbbell)", displayName: "Chest-supported DB row",
                             sets: 3, repsLow: 10, repsHigh: 12, weight: 20, restSeconds: 90),
                PlanExercise(id: "a-lateral", name: "Lateral Raise (Dumbbell)", displayName: "Lateral raise",
                             sets: 3, repsLow: 15, repsHigh: 20, weight: 5, restSeconds: 60, supersetGroup: "a1"),
                PlanExercise(id: "a-facepull", name: "Face Pull (Band)", displayName: "Band face pull",
                             sets: 3, repsLow: 15, repsHigh: 15, weight: nil, loadNote: "light band", restSeconds: 60, supersetGroup: "a1"),
                PlanExercise(id: "a-reardelt", name: "3-Way Incline Rear Delt Fly", displayName: "Incline 3-way rear delt fly",
                             sets: 2, repsLow: 8, repsHigh: 8, weight: 5, restSeconds: 60),
                PlanExercise(id: "a-curl", name: "Bicep Curl (Dumbbell)", displayName: "DB bicep curl",
                             sets: 3, repsLow: 10, repsHigh: 12, weight: 10, restSeconds: 60, supersetGroup: "a2"),
                PlanExercise(id: "a-skull", name: "Skullcrusher (Dumbbell)", displayName: "DB skullcrusher",
                             sets: 3, repsLow: 10, repsHigh: 12, weight: 10, restSeconds: 60, supersetGroup: "a2"),
            ]
        ),
        PlanDay(
            id: "B",
            name: "Moderate legs + upper",
            warmupNote: warmup,
            exercises: [
                PlanExercise(id: "b-pullapart", name: "Band Pull Apart", displayName: "Band pull-apart",
                             sets: 2, repsLow: 15, repsHigh: 15, weight: nil, loadNote: "light band", restSeconds: 30),
                PlanExercise(id: "b-extrot", name: "External Rotation (Band)", displayName: "Band external rotation",
                             sets: 2, repsLow: 12, repsHigh: 12, weight: nil, loadNote: "light band", restSeconds: 30, perSide: true),
                PlanExercise(id: "b-hipthrust", name: "Hip Thrust (Barbell)", displayName: "Barbell hip thrust",
                             sets: 3, repsLow: 8, repsHigh: 10, weight: 85, restSeconds: 120),
                PlanExercise(id: "b-goblet", name: "Goblet Squat (Kettlebell)", displayName: "Goblet squat (KB)",
                             sets: 3, repsLow: 8, repsHigh: 10, weight: 35, restSeconds: 120),
                PlanExercise(id: "b-rdl", name: "Romanian Deadlift (Barbell)", displayName: "Romanian deadlift",
                             sets: 3, repsLow: 8, repsHigh: 8, weight: 75, restSeconds: 120),
                PlanExercise(id: "b-landmine", name: "Landmine Press", displayName: "Landmine press",
                             sets: 3, repsLow: 8, repsHigh: 10, weight: 15, restSeconds: 60, supersetGroup: "b1", perSide: true),
                PlanExercise(id: "b-facepull", name: "Face Pull (Band)", displayName: "Band face pull",
                             sets: 3, repsLow: 15, repsHigh: 15, weight: nil, loadNote: "light band", restSeconds: 60, supersetGroup: "b1"),
                PlanExercise(id: "b-row", name: "Bent Over One Arm Row (Dumbbell)", displayName: "One-arm DB row",
                             sets: 3, repsLow: 10, repsHigh: 10, weight: 25, restSeconds: 75, perSide: true),
                PlanExercise(id: "b-hammer", name: "Hammer Curl (Dumbbell)", displayName: "Hammer curl",
                             sets: 2, repsLow: 12, repsHigh: 12, weight: 10, restSeconds: 60, supersetGroup: "b2"),
                PlanExercise(id: "b-pushdown", name: "Triceps Pushdown (Band)", displayName: "Band triceps pushdown",
                             sets: 2, repsLow: 12, repsHigh: 12, weight: nil, loadNote: "medium band", restSeconds: 60, supersetGroup: "b2"),
                PlanExercise(id: "b-kneeraise", name: "Hanging Knee Raise", displayName: "Hanging knee raise",
                             sets: 2, repsLow: 10, repsHigh: 10, weight: nil, loadNote: "bodyweight", restSeconds: 60, isOptional: true),
            ]
        ),
    ])
}
