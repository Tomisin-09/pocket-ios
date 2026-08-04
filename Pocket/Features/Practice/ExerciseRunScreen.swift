import SwiftUI

/// The **one place** that decides which run screen an exercise gets (ADR 0136). Almost every template
/// runs the tempo ramp in `ExerciseRunView`; a **freeform** block has no tempo and no ramp (F3), so it
/// runs `FreeformRunView` instead.
///
/// A router rather than three `if`s at three call sites — the routine player, the library's row, and
/// the library's push-into-run-after-create. That is exactly the shape ADR 0128 had to unpick for
/// exercise *creation*, where a second host silently missed a feature the first one gained: nothing
/// about a missing branch is checked by the compiler, and a freeform block routed to `ExerciseRunView`
/// wouldn't crash — it would quietly hand the player a ramp for a drill that has no tempo.
struct ExerciseRunScreen: View {
    let exercise: Exercise
    /// Routine-session chrome when this is a block in a routine; `nil` standalone.
    var routineContext: RoutineRunContext?

    var body: some View {
        if exercise.template == .freeform {
            FreeformRunView(exercise: exercise, routineContext: routineContext)
        } else {
            ExerciseRunView(exercise: exercise, routineContext: routineContext)
        }
    }
}
