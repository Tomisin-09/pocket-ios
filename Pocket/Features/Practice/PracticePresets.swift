import Foundation
import SwiftData

/// Curated, **in-house** starter exercises (ADR 0046, Phase A) seeded **once** on first launch so a
/// new Practice space isn't empty. These are universal technique drills authored in-house — encode
/// the method, never ship third-party material (the content strategy) — not lifted from any source.
///
/// After seeding each is a perfectly ordinary `Exercise`: fully editable, fully deletable, and
/// **deleted stays deleted**. The one-time `UserDefaults` flag (not an "is the store empty?" check)
/// is what makes deletion stick — an empty Practice means the user cleared the presets, not that
/// they were never seeded — so we never re-seed and they read as a friendly starting point, not
/// fixtures.
enum PracticePresets {
    /// The seed spec for one preset: name, a **seed** command tempo (modest on purpose — the player
    /// re-anchors to their own command on the first run), the subdivision "feel", tags, and a
    /// one-line how-to note.
    struct Spec {
        let name: String
        let command: Int
        let subdivision: Subdivision
        let tags: [String]
        let notes: String
    }

    /// The shipped set — small enough not to crowd an empty space, broad enough to cover the core
    /// fretting / picking / rhythm skills.
    static let specs: [Spec] = [
        Spec(name: "Spider Walk", command: 80, subdivision: .sixteenths,
             tags: ["warmup", "synchronization"],
             notes: "One finger per fret, 1-2-3-4 up the strings and back. Keep both hands locked "
                  + "to the click."),
        Spec(name: "Alternate Picking", command: 90, subdivision: .sixteenths,
             tags: ["picking", "technique"],
             notes: "Strict down-up on one string. Even volume, even spacing — let the click "
                  + "expose any rushing."),
        Spec(name: "Chord Changes", command: 70, subdivision: .none,
             tags: ["rhythm", "fretting"],
             notes: "Change chord cleanly on beat 1 — G, C, D, repeat. Land all fingers together."),
        Spec(name: "Scale Runs", command: 80, subdivision: .eighths,
             tags: ["scales", "coordination"],
             notes: "One octave up and down. Pick hand and fret hand land exactly together on each "
                  + "click."),
        Spec(name: "String Skipping", command: 75, subdivision: .eighths,
             tags: ["picking", "accuracy"],
             notes: "Skip a string between each note. Accuracy over speed — every note clean before "
                  + "you push the tempo."),
        Spec(name: "Legato", command: 85, subdivision: .sixteenths,
             tags: ["legato", "fretting"],
             notes: "Pick only the first note; hammer and pull the rest. Keep all four notes even "
                  + "in volume.")
    ]

    /// Build the preset exercises (un-inserted), each through the shared `commandAnchored` factory
    /// so the working floor + reach derive identically to a user-created drill (the single creation
    /// path, ADR 0046). Pure — unit-tested without a store.
    static func makeExercises() -> [Exercise] {
        specs.map { spec in
            Exercise.commandAnchored(name: spec.name, command: spec.command,
                                     subdivision: spec.subdivision, tags: spec.tags,
                                     notes: spec.notes)
        }
    }

    /// `UserDefaults` key recording that the one-time seed has run. Versioned so a future curated
    /// set could seed a second batch under a new key without disturbing this one.
    static let seededDefaultsKey = "practicePresetsSeeded.v1"

    /// Seed the curated presets **once, ever**. No-op after the first successful run (guarded by
    /// `seededDefaultsKey`), so deleted presets never return. Safe to call on every launch.
    static func seedIfNeeded(into context: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: seededDefaultsKey) else { return }
        for exercise in makeExercises() { context.insert(exercise) }
        try? context.save()
        defaults.set(true, forKey: seededDefaultsKey)
    }
}
