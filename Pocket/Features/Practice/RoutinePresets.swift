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

    /// The seed spec for one routine: a name and its ordered blocks.
    struct Spec {
        let name: String
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

    /// The shipped set — three routines, enough to show what a routine *is* (mixed drills with rests,
    /// one focus per routine) without crowding an empty space.
    static let specs: [Spec] = [
        Spec(name: "Morning Warm-up",
             blocks: [.exercise(spiderWalk), .exercise(chromaticWarmup),
                      .rest, .exercise(alternatePicking)]),
        Spec(name: "Picking Builder",
             blocks: [.exercise(alternatePicking), .exercise(stringSkipping),
                      .rest, .exercise(legato)]),
        Spec(name: "Rhythm & Changes",
             blocks: [.exercise(chordChanges), .exercise(popChanges),
                      .rest, .exercise(groovePopChanges)])
    ]

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
        for item in items { item.routine = routine }
        routine.items = items
        return routine
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
