import SwiftUI

/// The screen a `JournalOwnerRoute` opens (ADR 0142) — the view half of the owner-caption link, kept
/// apart from the pure routing so the rules stay testable.
///
/// Each case lands on the unit's **ordinary** run screen, the same one the library pushes: an
/// exercise through `ExerciseRunScreen` (which routes a freeform block onward, ADR 0136), and a loop
/// through the screen for the mode the route resolved. No bespoke "journal detail" surface — a note
/// is about a unit, and the unit already has a home.
struct JournalOwnerDestinationView: View {
    let route: JournalOwnerRoute

    var body: some View {
        switch route {
        case .exercise(let exercise):
            ExerciseRunScreen(exercise: exercise)
        case .loop(let loop, let mode):
            switch mode {
            case .trainer: LoopRunView(loop: loop)
            case .ear: EarTrainingScreen(loop: loop)
            case .improvise: ImproviseScreen(loop: loop)
            }
        }
    }
}
