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
    /// re-anchors to their own command on the first run), the subdivision "feel", tags, a one-line
    /// how-to note, the meter, and an optional **content template** payload (ADR 0065 T9 — a
    /// strumming preset ships a real pattern).
    struct Spec {
        let name: String
        let command: Int
        let subdivision: Subdivision
        let tags: [String]
        let notes: String
        var template: ExerciseTemplate = .basic
        var beatsPerBar: Int = 4
        var strum: StrumPattern?
        var fretboard: FretboardContent?
        var chords: ChordProgression?
    }

    /// The shipped set — small enough not to crowd an empty space, broad enough to cover the core
    /// fretting / picking / rhythm skills.
    static let specs: [Spec] = [
        Spec(name: "Spider Walk", command: 80, subdivision: .sixteenths,
             tags: ["warmup", "synchronization"],
             notes: "One finger per fret, 1-2-3-4 up the strings and back. Keep both hands locked "
                  + "to the click.",
             template: .warmup),
        Spec(name: "Alternate Picking", command: 90, subdivision: .sixteenths,
             tags: ["picking", "technique"],
             notes: "Strict down-up on one string. Even volume, even spacing — let the click "
                  + "expose any rushing.",
             template: .picking),
        Spec(name: "Chord Changes", command: 70, subdivision: .none,
             tags: ["rhythm", "fretting"],
             notes: "Change chord cleanly on beat 1 — G, C, D, repeat. Land all fingers together.",
             template: .chords),
        Spec(name: "Scale Runs", command: 80, subdivision: .eighths,
             tags: ["scales", "coordination"],
             notes: "One octave up and down. Pick hand and fret hand land exactly together on each "
                  + "click.",
             template: .scales),
        Spec(name: "String Skipping", command: 75, subdivision: .eighths,
             tags: ["picking", "accuracy"],
             notes: "Skip a string between each note. Accuracy over speed — every note clean before "
                  + "you push the tempo.",
             template: .picking),
        Spec(name: "Legato", command: 85, subdivision: .sixteenths,
             tags: ["legato", "fretting"],
             notes: "Pick only the first note; hammer and pull the rest. Keep all four notes even "
                  + "in volume.",
             template: .legato)
    ]

    /// The **content-template** batch (ADR 0065 T9) — seeded under a *second* key so an existing
    /// user who already has the v1 set above gains these on the next launch without disturbing
    /// (or re-seeding) their v1 presets. Each ships a real template payload.
    static let templateSpecs: [Spec] = [
        Spec(name: "Strumming — D DU UDU", command: 80, subdivision: .eighths,
             tags: ["rhythm", "strumming"],
             notes: "The folk pattern: down, then down-up, then up-down-up. Keep the strumming hand "
                  + "swinging in steady eighths — the rests are ghost strokes you feel but don't "
                  + "sound.",
             template: .strumming,
             strum: .folk)
    ]

    /// The **fretboard** batch (ADR 0065 build 2) — seeded under a *third* key so a user who already
    /// has the v1/v2 sets gains it on the next launch without disturbing them. Ships a real generated
    /// run so the animated board renderer *and* the generative authoring are exercised by content.
    static let fretboardSpecs: [Spec] = [
        Spec(name: "Chromatic Warm-up", command: 80, subdivision: .eighths,
             tags: ["warmup", "synchronization"],
             notes: "One finger per fret — 1-2-3-4 up every string from the low E to the high e and "
                  + "back. Watch the note walk the board and land both hands exactly on the click.",
             template: .warmup,
             fretboard: .run(.chromaticWarmup))
    ]

    /// The **scale library** batch (ADR 0065 build 2, Slice 2) — seeded under a *fourth* key so a user
    /// who already has the v1–v3 sets gains it on the next launch. Ships a real preprogrammed scale run
    /// so the scale-library editor and renderer are exercised by content.
    static let scaleSpecs: [Spec] = [
        Spec(name: "A Minor Pentatonic", command: 80, subdivision: .eighths,
             tags: ["scales", "lead"],
             notes: "The box-1 minor pentatonic from the low E's 5th fret, two octaves up and back. "
                  + "Pick and fret hands land together on every click.",
             template: .scales,
             fretboard: .scale(.aMinorPentatonic))
    ]

    /// The **arpeggio library** batch (ADR 0065 build 2, Slice 3) — seeded under a *fifth* key. Ships a
    /// real preprogrammed arpeggio run so the arpeggio editor and renderer are exercised by content.
    static let arpeggioSpecs: [Spec] = [
        Spec(name: "A Minor 7 Arpeggio", command: 80, subdivision: .eighths,
             tags: ["arpeggios", "lead"],
             notes: "The A minor 7 chord tones (R ♭3 5 ♭7) in the CAGED E-shape box, two octaves up "
                  + "and back. Target the chord tones cleanly on every click.",
             template: .arpeggios,
             fretboard: .arpeggio(.aMinorSeventh))
    ]

    /// The **chords** batch (ADR 0065, Chords template) — seeded under a *sixth* key. Ships a real
    /// chord progression so the chord-diagram renderer and the progression editor are exercised by
    /// content. (The v1 "Chord Changes" drill predates the renderer and stays a plain tempo drill.)
    static let chordSpecs: [Spec] = [
        Spec(name: "Pop Changes — G · D · Em · C", command: 70, subdivision: .none,
             tags: ["chords", "rhythm"],
             notes: "The I–V–vi–IV turnaround, one bar each. Land every finger of the next shape "
                  + "together, right on beat 1 — let the click expose any late changes.",
             template: .chords,
             chords: .gMajorPop)
    ]

    /// The **strumming accents/mutes** batch (ADR 0065, strumming slice 2) — seeded under a *seventh*
    /// key. Ships a real pattern using the muted-chuck and accent vocabulary so the upgraded editor
    /// and lane are exercised by content, not just the plain folk pattern from v2.
    static let syncopatedMuteSpecs: [Spec] = [
        Spec(name: "Strumming — Syncopated Mute", command: 78, subdivision: .eighths,
             tags: ["rhythm", "strumming"],
             notes: "Down, rest, down, muted chuck, rest, accented up, down, up. Keep the chuck short "
                  + "and percussive, and dig in on the accent — everything else stays even.",
             template: .strumming,
             strum: .syncopatedMute)
    ]

    /// Build the preset exercises (un-inserted) for a given batch, each through the shared
    /// `commandAnchored` factory so the working floor + reach derive identically to a user-created
    /// drill (the single creation path, ADR 0046). Applies any content-template payload (T9).
    /// Pure — unit-tested without a store.
    static func makeExercises(_ specs: [Spec] = specs) -> [Exercise] {
        specs.map { spec in
            let exercise = Exercise.commandAnchored(
                name: spec.name, command: spec.command,
                beatsPerBar: spec.beatsPerBar,
                subdivision: spec.subdivision, template: spec.template,
                tags: spec.tags, notes: spec.notes)
            if let strum = spec.strum { exercise.setStrumPattern(strum) }
            if let fretboard = spec.fretboard { exercise.setFretboardContent(fretboard) }
            if let chords = spec.chords { exercise.setChordProgression(chords) }
            return exercise
        }
    }

    /// `UserDefaults` keys recording that each one-time seed batch has run. Versioned so a new
    /// curated batch seeds under its own key without disturbing (or re-seeding) an earlier one.
    static let seededDefaultsKey = "practicePresetsSeeded.v1"
    static let seededTemplateDefaultsKey = "practicePresetsSeeded.v2"
    static let seededFretboardDefaultsKey = "practicePresetsSeeded.v3"
    static let seededScaleDefaultsKey = "practicePresetsSeeded.v4"
    static let seededArpeggioDefaultsKey = "practicePresetsSeeded.v5"
    static let seededChordDefaultsKey = "practicePresetsSeeded.v6"
    static let seededSyncopatedMuteDefaultsKey = "practicePresetsSeeded.v7"

    /// Seed the curated presets **once each, ever**: the v1 technique drills, the v2 strumming batch,
    /// the v3 fretboard warm-up, the v4 scale-library batch, the v5 arpeggio batch, the v6 chords
    /// batch, then the v7 accent/mute strumming batch, each guarded by its own key so a deleted
    /// preset never returns and an existing user picks up each newer batch additively. Safe to call
    /// on every launch.
    static func seedIfNeeded(into context: ModelContext, defaults: UserDefaults = .standard) {
        seedBatch(specs, key: seededDefaultsKey, into: context, defaults: defaults)
        seedBatch(templateSpecs, key: seededTemplateDefaultsKey, into: context, defaults: defaults)
        seedBatch(fretboardSpecs, key: seededFretboardDefaultsKey, into: context, defaults: defaults)
        seedBatch(scaleSpecs, key: seededScaleDefaultsKey, into: context, defaults: defaults)
        seedBatch(arpeggioSpecs, key: seededArpeggioDefaultsKey, into: context, defaults: defaults)
        seedBatch(chordSpecs, key: seededChordDefaultsKey, into: context, defaults: defaults)
        seedBatch(syncopatedMuteSpecs, key: seededSyncopatedMuteDefaultsKey, into: context, defaults: defaults)
    }

    /// Seed one batch once, guarded by its `key`. No-op after its first successful run.
    private static func seedBatch(_ specs: [Spec], key: String,
                                  into context: ModelContext, defaults: UserDefaults) {
        guard !defaults.bool(forKey: key) else { return }
        for exercise in makeExercises(specs) { context.insert(exercise) }
        try? context.save()
        defaults.set(true, forKey: key)
    }
}
