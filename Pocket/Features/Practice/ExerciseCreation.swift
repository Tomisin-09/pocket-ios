import Foundation
import SwiftData

extension Exercise {
    /// The **single creation path** for a command-anchored exercise (ADR 0046): build one from a
    /// name and the **command** tempo, deriving the warm-up **working** floor and the **reach**
    /// from it via pure `TempoStretch`. Both Practice's create sheet and the metronome automator's
    /// "Save as exercise" discovery seam funnel through here, so the derivation lives in one place
    /// and the two entry points can never drift (the ADR's "single creation path" risk).
    ///
    /// Returns an **un-inserted** model — the caller inserts into its own `modelContext` — so this
    /// stays a pure factory and the same call works from any screen.
    ///
    /// `notesPerBeat` / `template` / `tags` / `notes` default to the bare values the two interactive
    /// entry points (Practice's create sheet, the automator seam) use; the **preset seeder** passes
    /// them to give each curated drill its template, feel, and how-to note while still deriving
    /// working/reach identically.
    ///
    /// `notesPerBeat` states the drill's **rhythm** (ADR 0121) — `nil` for the interactive paths,
    /// which state none, and a real value for the presets that do. The seeded command is bound to it
    /// straight away, so a curated drill's tempo carries its rhythm from the moment it exists rather
    /// than waiting for the backfill.
    static func commandAnchored(name: String,
                                command: Int,
                                beatsPerBar: Int = 4,
                                noteValue: Int = 4,
                                notesPerBeat: Int? = nil,
                                template: ExerciseTemplate = .basic,
                                instrument: Instrument = .guitar,
                                tags: [String] = [],
                                notes: String = "") -> Exercise {
        let working = max(StandaloneMetronomeEngine.bpmRange.lowerBound,
                          TempoStretch.warmupFloorBPM(forCommand: command))
        return Exercise(name: name,
                        currentTempo: working,
                        commandTempo: command,
                        targetTempo: TempoStretch.targetBPM(forCommand: command),
                        beatsPerBar: beatsPerBar,
                        noteValue: noteValue,
                        notesPerBeat: notesPerBeat,
                        commandNotesPerBeat: notesPerBeat,
                        template: template,
                        instrument: instrument,
                        tags: tags,
                        notes: notes)
    }
}

extension NewExercisePlan {
    /// The **single insert path** for an interactively created exercise — everything that has to
    /// happen between "the player tapped Create" and "the drill exists": build it through the
    /// factory above, encode the authored payload, bind the command to that payload's rhythm
    /// (ADR 0121), insert, attach the picked songs (ADR 0111), and report the creation (ADR 0120).
    ///
    /// A **freeform** block's payload (ADR 0136) is the plan's `notes`, and it rides through the
    /// factory rather than being encoded here: it is a plain attribute, so unlike `linkedSongs` it can
    /// be set before the insert. The tempo fields it carries are the factory's derivations from a
    /// command the create step never shows and nothing reads (F3).
    ///
    /// **Both hosts of `NewExerciseSheet` call this**: Practice's `+` (`ExerciseLibraryView`) and the
    /// metronome automator's "Save as exercise" seam (`MetronomeAutomatorPanel`). They share the
    /// sheet, so they must share the insert too — before this existed each wrote its own, and
    /// anything creation gained had to be written twice in two files. The song link was added to one
    /// and silently missing from the other, which is invisible: the shared form still showed the
    /// picker, Create still worked, and only the link was gone. Nothing about consuming a
    /// `NewExercisePlan` field is checked by the compiler — it flags a struct's missing *writers*,
    /// never its missing *readers*. **Put new creation behaviour here and nowhere else.**
    ///
    /// Deliberately hung off `NewExercisePlan` rather than `commandAnchored`: only the two
    /// interactive entry points build a plan, whereas the **preset seeder** calls the factory
    /// directly, so a hook there would also fire for the six drills a fresh install seeds — ADR 0120
    /// recorded that trap for the `exerciseCreated` event. A plan is the thing that means *a person
    /// just authored this*.
    ///
    /// Returns the inserted exercise so a host can stage its own follow-on (the library pushes
    /// straight into the run screen); `nil` when there's nothing to create. The form already gates
    /// Create on a non-empty name, so the guard is belt-and-braces — but it belongs on the shared
    /// path rather than in one host's copy.
    @MainActor
    @discardableResult
    func finalise(in context: ModelContext) -> Exercise? {
        guard !name.isEmpty else { return nil }
        let exercise = Exercise.commandAnchored(name: name, command: command,
                                                beatsPerBar: signature.beats,
                                                noteValue: signature.noteValue,
                                                template: template,
                                                instrument: instrument,
                                                notes: notes)
        exercise.awayFromInstrument = awayFromInstrument
        if let strum { exercise.setStrumPattern(strum) }
        if let fretboard { exercise.setFretboardContent(fretboard) }
        if let chords { exercise.setChordProgression(chords) }
        if let strumChords { exercise.setStrumChordSheet(strumChords) }
        // The rhythm is whatever the authored content states, so the command can only be bound to it
        // once the payload is on (ADR 0121).
        exercise.bindCommandRhythmToContent()
        context.insert(exercise)
        // Songs attach only *after* the insert — assigning a relationship on a model that isn't in a
        // context yet doesn't stick (the same ordering constraint `UnitDuplication` documents).
        if !songs.isEmpty { exercise.linkedSongs = songs }
        Analytics.send(.exerciseCreated(template: template, instrument: instrument))
        return exercise
    }
}
