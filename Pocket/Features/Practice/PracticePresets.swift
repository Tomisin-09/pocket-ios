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
    /// re-anchors to their own command on the first run), the **rhythm** it's measured in, tags, a
    /// one-line how-to note, the meter, and an optional **content template** payload (ADR 0065 T9 —
    /// a strumming preset ships a real pattern).
    struct Spec {
        let name: String
        /// Stable provenance identifier stamped onto the seeded `Exercise.presetSlug` (ADR 0112). A
        /// **frozen** kebab-case id — the one-time backfill keys off it, and it is what
        /// `AccessPolicy.freeTasteSlugs` would match on if a free line ever returns (ADR 0144 D3), so
        /// it must never change even if `name` is reworded.
        let slug: String
        let command: Int
        /// The drill's own rhythm — notes per beat — for a preset whose **content** declares none
        /// (ADR 0121). `nil` for every batch that ships a payload: there the payload states it, and a
        /// second copy here could only drift from it.
        var noteRate: Int?
        let tags: [String]
        let notes: String
        var template: ExerciseTemplate = .basic
        var beatsPerBar: Int = 4
        var strum: StrumPattern?
        var fretboard: FretboardContent?
        var chords: ChordProgression?
        var strumChords: StrumChordSheet?
    }

    /// The shipped set — small enough not to crowd an empty space, broad enough to cover the core
    /// fretting / picking / rhythm skills.
    static let specs: [Spec] = [
        Spec(name: "Spider Walk", slug: "spider-walk", command: 80, noteRate: 4,
             tags: ["warmup", "synchronization"],
             notes: "One finger per fret, 1-2-3-4 up the strings and back. Keep both hands locked "
                  + "to the click.",
             template: .warmup),
        Spec(name: "Alternate Picking", slug: "alternate-picking", command: 90, noteRate: 4,
             tags: ["picking", "technique"],
             notes: "Strict down-up on one string. Even volume, even spacing — let the click "
                  + "expose any rushing.",
             template: .picking),
        Spec(name: "Chord Changes", slug: "chord-changes", command: 70, noteRate: nil,
             tags: ["rhythm", "fretting"],
             notes: "Change chord cleanly on beat 1 — G, C, D, repeat. Land all fingers together.",
             template: .chords),
        Spec(name: "Scale Runs", slug: "scale-runs", command: 80, noteRate: 2,
             tags: ["scales", "coordination"],
             notes: "One octave up and down. Pick hand and fret hand land exactly together on each "
                  + "click.",
             template: .scales),
        Spec(name: "String Skipping", slug: "string-skipping", command: 75, noteRate: 2,
             tags: ["picking", "accuracy"],
             notes: "Skip a string between each note. Accuracy over speed — every note clean before "
                  + "you push the tempo.",
             template: .picking),
        Spec(name: "Legato", slug: "legato", command: 85, noteRate: 4,
             tags: ["legato", "fretting"],
             notes: "Pick only the first note; hammer and pull the rest. Keep all four notes even "
                  + "in volume.",
             template: .legato)
    ]

    /// The **content-template** batch (ADR 0065 T9) — seeded under a *second* key so an existing
    /// user who already has the v1 set above gains these on the next launch without disturbing
    /// (or re-seeding) their v1 presets. Each ships a real template payload.
    static let templateSpecs: [Spec] = [
        Spec(name: "Strumming — D DU UDU", slug: "strumming-folk", command: 80,
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
        Spec(name: "Chromatic Warm-up", slug: "chromatic-warmup", command: 80,
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
        Spec(name: "A Minor Pentatonic", slug: "a-minor-pentatonic", command: 80,
             tags: ["scales", "lead"],
             notes: "The box-1 minor pentatonic from the low E's 5th fret, two octaves up and back. "
                  + "Pick and fret hands land together on every click.",
             template: .scales,
             fretboard: .scale(.aMinorPentatonic))
    ]

    /// The **scale layouts** batch (ADR 0083 S4) — seeded under its own key so a user who already has
    /// the earlier scale set gains the two neck-spanning layouts on the next launch. Ships a real
    /// extended-diagonal and a 3-notes-per-string run so both new placement rules are exercised by
    /// content, and so the following viewport and box focus (S5/S2b) have a climbing shape to show.
    static let scaleLayoutSpecs: [Spec] = [
        Spec(name: "A Minor Pentatonic — Extended", slug: "a-minor-pentatonic-extended",
             command: 80,
             tags: ["scales", "lead"],
             notes: "One diagonal run linking three pentatonic boxes up the neck — slide up on the A "
                  + "and G strings to shift into the next box. Watch the board follow the climb.",
             template: .scales,
             fretboard: .scale(.aMinorPentatonicExtended)),
        Spec(name: "G Major — 3 Notes Per String", slug: "g-major-three-per-string", command: 80,
             tags: ["scales", "technique"],
             notes: "Three tones on every string, low E to high e — the even, alternate-picking-friendly "
                  + "shape that spans the neck. Keep the picking hand relaxed and the notes even.",
             template: .scales,
             fretboard: .scale(.gMajorThreePerString))
    ]

    /// The **arpeggio library** batch (ADR 0065 build 2, Slice 3) — seeded under a *fifth* key. Ships a
    /// real preprogrammed arpeggio run so the arpeggio editor and renderer are exercised by content.
    static let arpeggioSpecs: [Spec] = [
        Spec(name: "A Minor 7 Arpeggio", slug: "a-minor-7-arpeggio", command: 80,
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
        Spec(name: "Pop Changes — G · D · Em · C", slug: "pop-changes", command: 70,
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
        Spec(name: "Strumming — Syncopated Mute", slug: "strumming-syncopated-mute", command: 78,
             tags: ["rhythm", "strumming"],
             notes: "Down, rest, down, muted chuck, rest, accented up, down, up. Keep the chuck short "
                  + "and percussive, and dig in on the accent — everything else stays even.",
             template: .strumming,
             strum: .syncopatedMute)
    ]

    /// The **strum & chords** batch (ADR 0065, strum↔chord composition) — seeded under an *eighth*
    /// key. Ships the folk groove under the pop turnaround so the composed renderer and its editor are
    /// exercised by content: one groove cycle per chord, by construction, since both hold one bar.
    static let strumChordsSpecs: [Spec] = [
        Spec(name: "Groove — Pop Changes", slug: "groove-pop-changes", command: 76,
             tags: ["rhythm", "strumming", "chords"],
             notes: "The folk D-DU-UDU groove under the G-D-Em-C turnaround — one full pattern cycle "
                  + "per chord. Keep the strumming hand swinging steady through every change.",
             template: .strumChords,
             strumChords: .popGroove)
    ]

    /// The **strumming expansion** batch (pocket-170) — seeded under a *tenth* key. Broadens the seeded
    /// rhythm vocabulary beyond the folk + syncopated-mute patterns with three more common grooves
    /// (continuous down-up eighths, the reggae off-beat "skank", and a boom-chick mute), so the
    /// strumming lane and its editor ship with a fuller starter set. In-house patterns (T8).
    static let strumExpansionSpecs: [Spec] = [
        Spec(name: "Strumming — Down-Up Eighths", slug: "strumming-down-up-eighths", command: 84,
             tags: ["rhythm", "strumming"],
             notes: "A stroke on every eighth, down-up-down-up. Keep the strumming hand swinging evenly "
                  + "from the elbow — the click exposes any stroke that rushes or drags.",
             template: .strumming,
             strum: .downUpEighths),
        Spec(name: "Strumming — Reggae Offbeat", slug: "strumming-reggae-offbeat", command: 76,
             tags: ["rhythm", "strumming"],
             notes: "Upstrokes on the off-beats only — the reggae 'skank'. Keep the hand moving down on "
                  + "each beat but sound only on the way back up, so the accents land between the clicks.",
             template: .strumming,
             strum: .offbeatUps),
        Spec(name: "Strumming — Boom-Chick", slug: "strumming-boom-chick", command: 80,
             tags: ["rhythm", "strumming"],
             notes: "A downstroke on the beat answered by a muted chuck on the off-beat — the boom-chick "
                  + "of a country accompaniment. Keep the chuck short and percussive, the down full.",
             template: .strumming,
             strum: .boomChick)
    ]

    /// The **scale sequencing** batch (pocket-173, ADR 0108) — seeded under an *eleventh* key. Ships the
    /// G major scale reordered into melodic thirds so the new sequence axis and its editor are exercised
    /// by content, not just the straight box run.
    static let scaleSequenceSpecs: [Spec] = [
        Spec(name: "G Major — in 3rds", slug: "g-major-in-thirds", command: 76,
             tags: ["scales", "technique"],
             notes: "The G major box played in thirds — 1-3-2-4-3-5 up and back. A classic pattern drill: "
                  + "keep the picking even and let the click expose any note that rushes.",
             template: .scales,
             fretboard: .scale(.gMajorInThirds))
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
                notesPerBeat: spec.noteRate, template: spec.template,
                tags: spec.tags, notes: spec.notes)
            exercise.presetSlug = spec.slug
            if let strum = spec.strum { exercise.setStrumPattern(strum) }
            if let fretboard = spec.fretboard { exercise.setFretboardContent(fretboard) }
            if let chords = spec.chords { exercise.setChordProgression(chords) }
            if let strumChords = spec.strumChords { exercise.setStrumChordSheet(strumChords) }
            // Bind the seeded command to the rhythm the drill actually resolves to — which for a
            // payload-carrying preset is the content's, and is only knowable *after* it's applied
            // (ADR 0121).
            exercise.bindCommandRhythmToContent()
            return exercise
        }
    }

    /// **Every** shipped preset spec across all batches, in seed order — the lookup table the
    /// provenance backfill matches against. Pure data; no store.
    static let allSpecs: [Spec] =
        specs + templateSpecs + fretboardSpecs + scaleSpecs + scaleLayoutSpecs + arpeggioSpecs
        + chordSpecs + syncopatedMuteSpecs + strumChordsSpecs + strumExpansionSpecs + scaleSequenceSpecs

    /// Pure lookup: the stable `slug` of the shipped spec whose `name` **and** `template` exactly
    /// match, or `nil` if none does. The unit-testable core of `backfillPresetSlugsIfNeeded` — no
    /// store, so a renamed preset simply doesn't match (and stays user-authored).
    static func slug(forName name: String, template: ExerciseTemplate) -> String? {
        allSpecs.first { $0.name == name && $0.template == template }?.slug
    }

    // MARK: - The first-run set

    /// The exercises a **fresh install** seeds — deliberately six, not the whole catalog.
    ///
    /// Chosen as the *union* of two sets that only half overlap: the four **free-taste** slugs a free
    /// player may run forever (ADR 0112), and the four exercises **`RoutinePresets`' Morning Routine
    /// strings together**. Routine blocks resolve *by name at seed time*, so seeding only the free
    /// taste would have shipped the demo routine with two blocks silently missing. The union is the
    /// smallest set where both stay whole — and, happily, every one of the six is runnable by a free
    /// player (two free-tier warm-ups plus the four freebies), so a new install has nothing locked in
    /// it and nothing broken.
    ///
    /// The **rest of the catalog is retired from seeding, not deleted**: `allSpecs` still lists every
    /// shipped spec, because it's the table the provenance backfill matches an older install's
    /// exercises against. An existing player keeps everything they were seeded — the batch flags below
    /// are already set on their device, so none of this re-runs and nothing is removed.
    static let firstRunSlugs: [String] = [
        "spider-walk",          // .warmup — free tier
        "chromatic-warmup",     // .warmup — free tier
        "alternate-picking",    // .picking — free taste
        "a-minor-pentatonic",   // .scales  — free taste
        "pop-changes",          // .chords  — free taste
        "legato"                // .legato  — free taste
    ]

    /// The first-run specs, resolved from `allSpecs` in `firstRunSlugs` order (which is also seed
    /// order). Built by lookup rather than re-declared, so a spec can never drift between the catalog
    /// and the set we actually ship.
    static let firstRunSpecs: [Spec] =
        firstRunSlugs.compactMap { slug in allSpecs.first { $0.slug == slug } }

    /// `UserDefaults` keys recording that each one-time seed batch has run. Versioned so a new
    /// curated batch seeds under its own key without disturbing (or re-seeding) an earlier one.
    static let seededDefaultsKey = "practicePresetsSeeded.v1"
    static let seededTemplateDefaultsKey = "practicePresetsSeeded.v2"
    static let seededFretboardDefaultsKey = "practicePresetsSeeded.v3"
    static let seededScaleDefaultsKey = "practicePresetsSeeded.v4"
    static let seededArpeggioDefaultsKey = "practicePresetsSeeded.v5"
    static let seededChordDefaultsKey = "practicePresetsSeeded.v6"
    static let seededSyncopatedMuteDefaultsKey = "practicePresetsSeeded.v7"
    static let seededStrumChordsDefaultsKey = "practicePresetsSeeded.v8"
    static let seededScaleLayoutDefaultsKey = "practicePresetsSeeded.v9"
    static let seededStrumExpansionDefaultsKey = "practicePresetsSeeded.v10"
    static let seededScaleSequenceDefaultsKey = "practicePresetsSeeded.v11"

    /// Seed the curated presets **once, ever**, guarded by the v1 key.
    ///
    /// A fresh install gets `firstRunSpecs` — the six-exercise first-run set (see above), not the
    /// whole catalog. The later batch keys (v2…v11) are **no longer seeded**: on an existing device
    /// they are already `true`, so that player keeps every drill they were given and nothing is
    /// removed; on a new device they simply never run, which is how the library arrives at six.
    /// Reusing the v1 key rather than minting a v12 is deliberate — a new key would re-seed the six
    /// onto existing installs that already have them, duplicating rows.
    ///
    /// Safe to call on every launch. The keys are retained below so the flags stay documented and a
    /// future curated batch can seed under its own new key without disturbing this one.
    static func seedIfNeeded(into context: ModelContext, defaults: UserDefaults = .standard) {
        seedBatch(firstRunSpecs, key: seededDefaultsKey, into: context, defaults: defaults)
    }

    /// `UserDefaults` key guarding the one-time provenance backfill (ADR 0112).
    static let presetSlugBackfillKey = "practicePresetSlugBackfill.v1"

    /// **One-time provenance backfill** (ADR 0112): stamp `presetSlug` onto presets that were seeded
    /// on an earlier build, before the slug field existed. Fetch **all** exercises (never an optional
    /// `#Predicate` — `presetSlug != nil` starves the main thread) and, for any with no slug yet,
    /// stamp the shipped spec whose name + template match. A renamed preset won't match and stays
    /// user-authored — acceptable, since players who had the app before the paywall are grandfathered.
    /// Guarded so it runs at most once; safe to call on every launch after `seedIfNeeded`.
    static func backfillPresetSlugsIfNeeded(into context: ModelContext,
                                            defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: presetSlugBackfillKey) else { return }
        let existing = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        for exercise in existing where exercise.presetSlug == nil {
            if let match = slug(forName: exercise.name, template: exercise.template) {
                exercise.presetSlug = match
            }
        }
        try? context.save()
        defaults.set(true, forKey: presetSlugBackfillKey)
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
