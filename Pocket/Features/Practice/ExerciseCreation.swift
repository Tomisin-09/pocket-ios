import Foundation

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
