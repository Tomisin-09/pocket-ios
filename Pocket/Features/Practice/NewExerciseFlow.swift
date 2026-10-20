import SwiftData
import SwiftUI

/// **Create a drill, then open it** (ADR 0046 / 0068): the create sheet, the insert, and the push to
/// the new drill's run screen once the sheet has gone.
///
/// One modifier because four places start it: the Exercises library's **+**, a category screen's
/// **New** (which skips the template step), the Practice hub's **New exercise** tile (ADR 0257
/// D5), and a reference's **Start an exercise from this** (ADR 0264 D5). The two-state hand-off below
/// is easy to get subtly wrong, so it is written once.
///
/// Open on create: a drill you just authored pushes straight to its run screen, so creating and
/// playing are one move instead of "create, find it in the list, tap it". The push is a `Bool`
/// rather than `.navigationDestination(item:)`, because a just-inserted model's `persistentModelID`
/// flips temporary→permanent on the first autosave and item-based presentation reads that as an
/// identity change and pops the screen (ADR 0090; `docs/swiftdata-gotchas.md`).
struct NewExerciseFlow: ViewModifier {
    @Binding var isPresented: Bool
    /// Set by a category screen: the sheet opens on that template's configure step. `nil` shows the
    /// template picker first.
    let fixedTemplate: ExerciseTemplate?
    /// Set by a reference's screen (ADR 0264 D5): a row of the source the drill is started from,
    /// which the insert files onto it. `nil` from every other door.
    let startingFrom: UUID?

    @Environment(\.modelContext) private var context
    /// The local profile (ADR 0113 S2): its self-rated experience seeds the command tempo, and its
    /// preferred instrument (ADR 0116) the neck.
    @Query private var profiles: [Profile]
    /// Written by `create` while the sheet is still up, then promoted to `opening` in `onDismiss`:
    /// presenting into a dismissing sheet drops the push.
    @State private var justCreated: Exercise?
    @State private var opening: Exercise?

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $isPresented, onDismiss: openJustCreated) {
                NewExerciseSheet(initialCommand: defaultCommand, fixedTemplate: fixedTemplate,
                                 defaultInstrument: defaultInstrument, onCreate: create)
            }
            .navigationDestination(isPresented: Binding(get: { opening != nil },
                                                        set: { if !$0 { opening = nil } })) {
                if let exercise = opening { ExerciseRunScreen(exercise: exercise) }
            }
    }

    /// The command tempo a fresh drill pre-fills: the profile's experience default when declared, else
    /// the engine floor — the same value `NewExerciseSheet` uses by default, so an untouched install is
    /// unchanged.
    private var defaultCommand: Int {
        profiles.first?.experience?.defaultCommandTempo ?? StandaloneMetronomeEngine.defaultCommandBPM
    }

    /// The profile's preferred instrument, else guitar. With a fixed template it is adjusted to one the
    /// template can be made on (ADR 0257 D5), since the step that would let the player choose is the
    /// one being skipped.
    private var defaultInstrument: Instrument {
        let preferred = profiles.first?.preferredInstrument ?? .guitar
        guard let fixedTemplate else { return preferred }
        return PracticeHubShelves.newDrillInstrument(for: fixedTemplate, preferred: preferred)
    }

    /// The insert is `plan.finalise(in:)`, shared with the metronome automator's save seam (ADR 0128),
    /// so creation behaviour is written once. What is left here is the haptic and the push.
    private func create(_ plan: NewExercisePlan) {
        var plan = plan
        plan.startedFromReference = startingFrom
        guard let exercise = plan.finalise(in: context) else { return }
        haptic(.medium)
        justCreated = exercise
    }

    private func openJustCreated() {
        guard let exercise = justCreated else { return }
        justCreated = nil
        opening = exercise
    }
}

extension View {
    /// Present the create sheet while `isPresented` is true, and open the drill it makes.
    /// `startingFrom` is a reference row the new drill takes (ADR 0264 D5).
    func newExerciseFlow(isPresented: Binding<Bool>, fixedTemplate: ExerciseTemplate? = nil,
                         startingFrom reference: UUID? = nil) -> some View {
        modifier(NewExerciseFlow(isPresented: isPresented, fixedTemplate: fixedTemplate, startingFrom: reference))
    }
}
