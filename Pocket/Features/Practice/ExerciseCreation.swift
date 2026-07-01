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
    /// `subdivision` / `tags` / `notes` default to the bare values the two interactive entry points
    /// (Practice's create sheet, the automator seam) use; the **preset seeder** passes them to give
    /// each curated drill its feel and how-to note while still deriving working/reach identically.
    static func commandAnchored(name: String,
                                command: Int,
                                beatsPerBar: Int = 4,
                                noteValue: Int = 4,
                                subdivision: Subdivision = .none,
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
                        subdivision: subdivision,
                        tags: tags,
                        notes: notes)
    }
}
