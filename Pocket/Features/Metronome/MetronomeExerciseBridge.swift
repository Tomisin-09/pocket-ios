import Foundation

/// Maps between a saved `MetronomeExercise` and the live `StandaloneMetronomeEngine` (ADR
/// 0043, slice 6). Kept in the feature layer (free functions) so the audio engine stays
/// free of the SwiftData model and vice-versa. `@MainActor` — it drives the main-actor
/// engine and SwiftData model from the UI.
@MainActor
enum MetronomeExerciseBridge {

    /// Apply a saved exercise's full configuration to the engine — tempo, time signature,
    /// subdivision, and the automator recipe. Order matters: the tempo is set first (it's the
    /// ramp's floor and a manual set clears any prior ramp), then the automator is armed from
    /// the recipe.
    static func apply(_ exercise: MetronomeExercise, to engine: StandaloneMetronomeEngine) {
        engine.setBPM(exercise.currentTempo)
        engine.setSubdivision(exercise.subdivision)
        engine.setTimeSignature(TimeSignature.forStored(beats: exercise.beatsPerBar,
                                                        noteValue: exercise.noteValue,
                                                        accentBeats: exercise.accentBeats))
        if exercise.automatorEnabled {
            engine.setAutomatorMode(exercise.automatorIntervalUnit == .bars ? .bars : .seconds)
            engine.setAutomatorStepBPM(exercise.automatorStepBPM)
            engine.setAutomatorIntervalCount(exercise.automatorIntervalCount)
            engine.setAutomatorCeiling(exercise.resolvedAutomatorCeiling)
        } else {
            engine.setAutomatorMode(.off)
        }
    }

    /// A new exercise capturing the engine's current configuration under `name`.
    static func capture(named name: String, from engine: StandaloneMetronomeEngine) -> MetronomeExercise {
        let exercise = MetronomeExercise(name: name)
        write(engine, into: exercise)
        return exercise
    }

    /// Overwrite an existing exercise's configuration with the engine's current state (the
    /// "update this preset" path), leaving its name, tags, notes, and date untouched.
    static func update(_ exercise: MetronomeExercise, from engine: StandaloneMetronomeEngine) {
        write(engine, into: exercise)
    }

    /// A throwaway, un-inserted exercise mirroring the engine's current state — for showing
    /// the to-be-saved configuration (via `configurationSummary`) in the update confirmation,
    /// so what's previewed is exactly what `update`/`capture` will write (floor included).
    static func preview(from engine: StandaloneMetronomeEngine) -> MetronomeExercise {
        capture(named: "", from: engine)
    }

    private static func write(_ engine: StandaloneMetronomeEngine, into exercise: MetronomeExercise) {
        // When a ramp is armed, save its **floor** (the tempo it started from), not the live
        // `bpm` — a finished ramp has climbed `bpm` to the ceiling, and capturing that would
        // store floor == ceiling. The floor is the captured `automatorStartBPM`.
        exercise.currentTempo = engine.automatorEnabled ? engine.automatorStartBPM : engine.bpm
        // No separate target UI until slice 7: the goal is the ramp ceiling when armed, else
        // the working tempo. Persisted so a loaded preset keeps a sensible target.
        exercise.targetTempo = engine.automatorEnabled ? engine.automatorCeiling : engine.bpm
        exercise.beatsPerBar = engine.timeSignature.beats
        exercise.noteValue = engine.timeSignature.noteValue
        exercise.accentBeats = engine.timeSignature.accentBeats
        exercise.subdivision = engine.subdivision
        exercise.automatorEnabled = engine.automatorEnabled
        exercise.automatorStepBPM = engine.automatorStepBPM
        exercise.automatorIntervalCount = engine.automatorIntervalCount
        exercise.automatorIntervalUnit = engine.automatorUnit
        exercise.automatorCeiling = engine.automatorEnabled ? engine.automatorCeiling : nil
    }
}
