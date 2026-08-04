import SwiftData
import SwiftUI

/// A **freeform block inside a routine**, opened by tapping it in the editor (ADR 0136).
///
/// The other exercise blocks push `ExerciseBlockPreview` — the template content, the tempo anchors and
/// the ramp staircase. A freeform block has **none of those**: no content the app can render, no
/// command tempo, no ramp to fit (F3). Pushing that screen for one drew a staircase the run will never
/// play and a command tempo nothing reads, which is exactly the confusion F1c set out to avoid.
///
/// So it gets the same treatment ear and improvise loop blocks already have (`RampLessBlockPreview`):
/// its own surface, showing only what is actually true of it: the player's instructions, the
/// optional click, and — since ADR 0141 — the block's length.
///
/// Unlike the other previews this one is **editable**, and deliberately so: for every other template
/// the routine editor is the wrong place to change the drill (its content is authored in its own
/// editor), but a freeform block's content *is* the text, and the moment you want to change it is the
/// moment you're looking at it in the routine you built it for.
struct FreeformBlockPreview: View {
    let exercise: Exercise
    /// The block being previewed, for its length. `nil` outside a routine.
    var block: RoutineItem?
    /// A binding onto the block's open-ended opt-out (`RoutineItem.usesAuthoredLength`, ADR 0130
    /// reused per ADR 0141 L4), carrying the editor's save discipline with it.
    var runsOpenEnded: Binding<Bool>?

    var body: some View {
        Form {
            FreeformInstructionsSection(exercise: exercise)
            FreeformMetronomeSection(exercise: exercise)
            if let block, let runsOpenEnded {
                // The same control ear and improvise blocks use (ADR 0141 L4) — a freeform block is
                // ramp-less in exactly the sense that ADR means.
                Section {
                    RampLessBlockLengthControl(runsOpenEnded: runsOpenEnded,
                                               minutes: runsOpenEnded.wrappedValue
                                                   ? nil : block.plannedMinutes,
                                               tint: PocketColor.practice)
                } header: {
                    Text("Length")
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(exercise.name.isEmpty ? "Your own practice" : exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .tint(PocketColor.practice)
    }
}

#Preview("Freeform block in a routine") {
    let exercise = Exercise.commandAnchored(
        name: "Sight-reading",
        command: 90,
        template: .freeform,
        notes: "Two pages from the Berklee book, first time through only. Don't stop to fix "
             + "anything — keep the pulse and take the mistakes.")
    return NavigationStack {
        FreeformBlockPreview(exercise: exercise)
    }
    .preferredColorScheme(.dark)
}
