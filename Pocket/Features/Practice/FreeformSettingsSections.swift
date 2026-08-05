import SwiftData
import SwiftUI

/// The **authoring surface for a freeform block** (ADR 0136), shared by the two places you reach one:
/// the exercise's information sheet (`ExerciseDetailSheet`) and its block in the routine editor
/// (`FreeformBlockPreview`). One definition, so the two can't drift into offering different controls
/// for the same thing.
///
/// Deliberately only two sections. A freeform block is *your instructions and, if you want it, a
/// pulse* — there is no ramp to tune, no command tempo to raise, and no content for the app to render.
/// Everything absent here is absent on purpose (F3).
///
/// Each control writes straight through and saves. That is the right discipline for discrete settings
/// — a toggle or a stepper is a decision, not a draft — and it matches the linked-songs rows rather
/// than the notes/mastery commit-on-Done.
struct FreeformInstructionsSection: View {
    @Bindable var exercise: Exercise
    @Environment(\.modelContext) private var modelContext

    /// Held locally and committed on blur/disappear, unlike the toggles: prose *is* a draft, and
    /// saving every keystroke would write to the store on each character.
    @State private var draft: String
    @FocusState private var draftFocused: Bool

    init(exercise: Exercise) {
        self.exercise = exercise
        _draft = State(initialValue: exercise.notes)
    }

    var body: some View {
        Section {
            TextField("What are you practising?", text: $draft, axis: .vertical)
                .lineLimit(4...12)
                .keyboardDoneButton()
                // Needs a `KeyboardFollowingScroll` around the host's container — both hosts
                // (`ExerciseDetailSheet`, `FreeformBlockPreview`) have one; inert if a third forgets.
                .scrollsIntoViewWhenFocused("instructions", focused: $draftFocused)
            // ADR 0139 O6 — player-declared, never inferred.
            Toggle("I can do this without my instrument", isOn: Binding(
                get: { exercise.awayFromInstrument },
                set: { exercise.awayFromInstrument = $0; try? modelContext.save() }))
        } header: {
            Text("Instructions")
        } footer: {
            Text("What you told yourself to do. This is the whole exercise, and you'll see it while "
                 + "you practise — nothing reads it but you.\n\nTick the box and this can turn up in "
                 + "an \u{201C}Away from your instrument\u{201D} session. We can't tell from what you "
                 + "wrote, so it's your call.")
        }
        .onDisappear(perform: commit)
    }

    private func commit() {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != exercise.notes else { return }
        exercise.notes = trimmed
        try? modelContext.save()
    }
}

/// The optional click. **Nothing fancy on purpose**: on/off, a tempo, a time signature. No ramp, no
/// reach, no promote, no subdivision — this is a pulse to practise against, not a drill to climb.
///
/// The tempo here is **not** a command tempo (ADR 0046). Command tempo is an achievement that anchors
/// a ramp and feeds the planner; this only says how fast the click ticks. That separation is what lets
/// a freeform block have a metronome and still honestly log `tempoBPM: nil`.
struct FreeformMetronomeSection: View {
    @Bindable var exercise: Exercise
    @Environment(\.modelContext) private var modelContext

    private let range = StandaloneMetronomeEngine.bpmRange

    var body: some View {
        Section {
            Toggle("Metronome", isOn: Binding(
                get: { exercise.clickEnabled },
                set: { exercise.clickEnabled = $0; try? modelContext.save() }))
            if exercise.clickEnabled {
                EditableTempoRow(label: "Tempo", caption: "BPM",
                                 value: exercise.clickBPM, tint: PocketColor.practice,
                                 onStep: { setBPM(exercise.clickBPM + $0) },
                                 onType: { setBPM($0) })
                Picker("Time signature", selection: Binding(
                    get: {
                        TimeSignature.forStored(beats: exercise.beatsPerBar,
                                                noteValue: exercise.noteValue,
                                                accentBeats: exercise.accentBeats)
                    },
                    set: { signature in
                        exercise.beatsPerBar = signature.beats
                        exercise.noteValue = signature.noteValue
                        exercise.accentBeats = signature.accentBeats
                        try? modelContext.save()
                    })) {
                        ForEach(TimeSignature.presets) { preset in
                            Text("\(preset.name) · \(preset.context)").tag(preset)
                        }
                    }
            }
        } header: {
            Text("Metronome")
        } footer: {
            Text(exercise.clickEnabled
                 ? "A plain click while this block runs — a pulse to work against, nothing more. "
                 + "It isn't a target and nothing climbs it, so this block still records no tempo."
                 : "Off by default. Most freeform practice — reading, transcribing, working a piece "
                 + "by hand — has no pulse at all.")
        }
    }

    private func setBPM(_ value: Int) {
        exercise.clickBPM = min(range.upperBound, max(range.lowerBound, value))
        try? modelContext.save()
    }
}
