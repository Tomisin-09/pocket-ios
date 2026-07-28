import Foundation
import SwiftData

/// Curated, **in-house** starter routines (ADR 0066 / 0071) seeded **once** on first launch so the
/// Routines library isn't empty — the cold-start unlock. Each is an ordinary `Routine` afterwards:
/// fully editable, fully deletable, and **deleted stays deleted** (the one-time `UserDefaults` flag,
/// not an "is the store empty?" check, is what makes that stick — mirroring `PracticePresets`).
///
/// **Exercise-only, by construction.** A preset routine can only reference units that exist at cold
/// start, and the only units seeded then are the `PracticePresets` exercises — loops and songs need
/// user-imported audio, which doesn't exist yet. So presets string the seeded **exercises** together
/// (the exercises-first / "exercises are the portable, shareable axis" direction, ADR 0064). Blocks
/// are resolved **by name**; a missing exercise (renamed / deleted) is simply skipped, and a routine
/// with no resolvable exercise is not seeded at all — the same graceful degradation the player uses
/// for orphaned blocks (ADR 0066 R5).
enum RoutinePresets {

    /// One block in a preset recipe: an exercise referenced by its (stable) preset name, or a rest.
    enum Block {
        case exercise(String)
        case rest
    }

    /// The seed spec for one routine: a name, a stable provenance slug, and its ordered blocks.
    struct Spec {
        let name: String
        /// Stable provenance identifier stamped onto the seeded `Routine.presetSlug` (ADR 0112). The
        /// free-taste run allowance and the one-time backfill both key off it, so it must never
        /// change even if `name` is reworded.
        let slug: String
        let blocks: [Block]
    }

    // Preset exercise names — must match `PracticePresets` exactly (that's the reference key).
    private static let spiderWalk = "Spider Walk"
    private static let alternatePicking = "Alternate Picking"
    private static let stringSkipping = "String Skipping"
    private static let legato = "Legato"
    private static let chordChanges = "Chord Changes"
    private static let chromaticWarmup = "Chromatic Warm-up"
    private static let popChanges = "Pop Changes — G · D · Em · C"
    private static let groovePopChanges = "Groove — Pop Changes"
    private static let aMinorPentatonic = "A Minor Pentatonic"

    /// The shipped set — three routines, enough to show what a routine *is* (mixed drills with rests,
    /// one focus per routine) without crowding an empty space.
    ///
    /// **Morning Routine is the free taste** (ADR 0112): every one of its blocks is already either a
    /// free-tier template (`.warmup`) or a free-taste exercise slug (`alternate-picking`,
    /// `a-minor-pentatonic`), so a free player running it reaches no Pro content — the routine is
    /// clean *by construction*, and must stay that way. It closes on the pentatonic box so the free
    /// taste covers **lead** playing too, not only warm-ups and picking. The other two deliberately
    /// are not clean: Picking Builder pulls in `string-skipping` (`.picking`) and Rhythm & Changes
    /// pulls in `chord-changes` (`.chords`) plus a `.strumChords` groove, so they read as the shop
    /// window for what Pro unlocks.
    static let specs: [Spec] = [
        Spec(name: "Morning Routine", slug: freeTasteSlug,
             blocks: [.exercise(spiderWalk), .exercise(chromaticWarmup),
                      .rest, .exercise(alternatePicking),
                      .rest, .exercise(aMinorPentatonic)]),
        Spec(name: "Picking Builder", slug: "picking-builder",
             blocks: [.exercise(alternatePicking), .exercise(stringSkipping),
                      .rest, .exercise(legato)]),
        Spec(name: "Rhythm & Changes", slug: "rhythm-and-changes",
             blocks: [.exercise(chordChanges), .exercise(popChanges),
                      .rest, .exercise(groovePopChanges)])
    ]

    /// The slug of the one curated routine a free player may **run** forever (ADR 0112). Frozen —
    /// `AccessPolicy.freeTasteRoutineSlugs` matches on it.
    static let freeTasteSlug = "morning-warm-up"

    /// Build one preset routine (un-inserted) from a name→exercise lookup, resolving each exercise
    /// block by name. Unresolved exercise blocks are skipped; a routine that resolves **no** exercise
    /// returns `nil` (a routine of only rests is pointless). Pure — unit-tested without a store.
    static func makeRoutine(_ spec: Spec, resolving lookup: [String: Exercise]) -> Routine? {
        var items: [RoutineItem] = []
        var resolvedAnExercise = false
        for block in spec.blocks {
            switch block {
            case .exercise(let name):
                guard let exercise = lookup[name] else { continue }
                items.append(.item(exercise, order: items.count))
                resolvedAnExercise = true
            case .rest:
                items.append(.rest(order: items.count))
            }
        }
        guard resolvedAnExercise else { return nil }
        let routine = Routine(name: spec.name)
        routine.presetSlug = spec.slug
        for item in items { item.routine = routine }
        routine.items = items
        return routine
    }

    /// Names a shipped routine used to carry, mapped to its (unchanged) slug — the backfill's memory.
    ///
    /// Renaming a spec would otherwise **Pro-lock the demo on every existing install**: the backfill
    /// matches by name, so an install seeded as "Morning Warm-up" would stop matching the moment the
    /// spec became "Morning Routine", never get stamped, and fail `isFreeTasteRoutine`. The slug is
    /// frozen precisely so a rename is cosmetic; this table is what makes that true for rows seeded
    /// before the rename. Any future rename must add its old name here.
    static let legacyNameSlugs: [String: String] = [
        "Morning Warm-up": freeTasteSlug     // renamed to "Morning Routine", 2026-07-28
    ]

    /// Pure lookup: the stable `slug` of the shipped spec whose `name` exactly matches — falling back
    /// to `legacyNameSlugs` for a spec that has since been renamed — or `nil` if none does. The
    /// unit-testable core of `backfillPresetSlugsIfNeeded`; no store, so a *user*-renamed routine
    /// simply doesn't match and stays user-built. Name alone is the key here (unlike the exercise
    /// backfill's name + template) because a `Routine` carries no template axis.
    static func slug(forName name: String) -> String? {
        specs.first { $0.name == name }?.slug ?? legacyNameSlugs[name]
    }

    /// `UserDefaults` key guarding the one-time provenance backfill (ADR 0112).
    static let presetSlugBackfillKey = "routinePresetSlugBackfill.v1"

    /// **One-time provenance backfill** (ADR 0112): stamp `presetSlug` onto curated routines seeded on
    /// an earlier build, before the slug field existed — without it, a player who already had the app
    /// would find their Morning Warm-up Pro-locked, since the free-taste allowance keys off the slug.
    /// Fetches **all** routines (never an optional `#Predicate` — `presetSlug != nil` starves the main
    /// thread) and stamps any unslugged one whose name matches a shipped spec. Guarded so it runs at
    /// most once; safe to call on every launch after `seedIfNeeded`.
    static func backfillPresetSlugsIfNeeded(into context: ModelContext,
                                            defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: presetSlugBackfillKey) else { return }
        let existing = (try? context.fetch(FetchDescriptor<Routine>())) ?? []
        for routine in existing where routine.presetSlug == nil {
            guard let match = slug(forName: routine.name) else { continue }
            routine.presetSlug = match
            // Carry a *cosmetic* rename through too, but only while the row still holds the old
            // shipped name — a player who renamed their copy keeps their name, untouched.
            if legacyNameSlugs[routine.name] != nil,
               let current = specs.first(where: { $0.slug == match })?.name {
                routine.name = current
            }
        }
        try? context.save()
        defaults.set(true, forKey: presetSlugBackfillKey)
    }

    /// `UserDefaults` key recording that the one-time seed has run. Versioned like `PracticePresets`
    /// so a future curated batch can seed under its own key without disturbing this one.
    static let seededDefaultsKey = "routinePresetsSeeded.v1"

    /// Seed the curated routines **once, ever**, guarded by `seededDefaultsKey`. Fetches the current
    /// exercises (the just-seeded presets on a fresh install) to resolve blocks by name. Safe to call
    /// on every launch, and must run **after** `PracticePresets.seedIfNeeded` so the exercises exist.
    static func seedIfNeeded(into context: ModelContext, defaults: UserDefaults = .standard) {
        guard !defaults.bool(forKey: seededDefaultsKey) else { return }
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let lookup = Dictionary(exercises.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })
        for spec in specs {
            guard let routine = makeRoutine(spec, resolving: lookup) else { continue }
            context.insert(routine)
            for item in routine.items { item.routine = routine; context.insert(item) }
        }
        try? context.save()
        defaults.set(true, forKey: seededDefaultsKey)
    }
}
