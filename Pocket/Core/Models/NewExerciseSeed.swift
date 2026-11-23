import Foundation

/// **What a door that already knows the exercise hands the New exercise form** (ADR 0313 D9). The form
/// opens on its template, instrument and name, with its content in place, and the player changes anything
/// before saving it. Nothing is saved until they do.
///
/// One door makes one today: *Practice as triads* on a progression in *My progressions*. Pure, so what it
/// opens on is unit-tested (`PracticeAsTriadsTests`) and the two buttons that make it can't disagree.
struct NewExerciseSeed: Equatable, Sendable {
    let template: ExerciseTemplate
    /// Triads is guitar only (D2), so a seed fixes the neck rather than taking the profile's.
    let instrument: Instrument
    /// The name the form opens on.
    let name: String
    /// The Triads run the Arpeggios editor opens on, under *Generate*.
    let triads: TriadRun
}

extension NewExerciseSeed {
    /// *Practice as triads* (D9): an Arpeggios exercise, generating Triads, with this progression chosen
    /// in the key it was written in, and D10's defaults for the rest (G‑B‑e, *Stay in frets* 3 to 7,
    /// Broken, eighths). Its name is the progression's with "as triads" after it.
    ///
    /// `nil` when no chord in it has a triad: no chords, or only power chords, which have no third (D5). A
    /// run of nothing but rests would open on a board that never lights.
    static func practiceAsTriads(name: String, steps: [ProgressionStep], tonic: Int?) -> NewExerciseSeed? {
        guard steps.contains(where: { $0.quality.triadQuality != nil }) else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        var run = TriadRun.starter
        run.tonic = ((tonic ?? ProgressionDraft.defaultTonic) % 12 + 12) % 12
        // The progression reads its own major or minor (D5). The key's other sources keep that reading,
        // so switching *Chords* to the key's seven stays in the progression's key.
        run.isMinor = steps.readsAsMinor
        run.source = .progression
        run.progression = TriadRun.Progression(name: trimmed, steps: steps)
        return NewExerciseSeed(template: .arpeggios, instrument: .guitar,
                               name: practiceAsTriadsTitle(for: trimmed), triads: run)
    }

    /// "Verse changes as triads". A progression always has a name, but one being edited can be cleared.
    static func practiceAsTriadsTitle(for name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.isEmpty ? "Progression" : trimmed) + " as triads"
    }
}

extension SavedProgression {
    /// *Practice as triads* from this progression as saved, or `nil` when it has no chord a triad plays.
    var practiceAsTriadsSeed: NewExerciseSeed? {
        NewExerciseSeed.practiceAsTriads(name: name, steps: steps, tonic: payload.tonic)
    }
}
