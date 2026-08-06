import Foundation

/// The **entitlement tier** a capability belongs to. Deliberately a two-case value with no associated
/// data — the *mechanism* that resolves `isPro` (StoreKit 2, a `StoreManager`) lives elsewhere; this
/// axis is pure, Foundation-only, and unit-testable per the "pure logic stays pure" rule (AGENTS.md).
///
/// **ADR 0144 retired the free content line**: every capability below is `.pro`, and the free surface
/// is the Toolkit, which contains no gates at all. `.free` is kept as a case because the *shape* of
/// the axis is the seam a future free line would return through (ADR 0144 D3) — not because anything
/// currently uses it.
enum AccessTier: Equatable {
    case free
    case pro
}

extension ExerciseTemplate {
    /// Whether **authoring** from this template requires Red Moon Pro. **Every template does**
    /// (ADR 0144 D1): there is no free-tier template family any more.
    ///
    /// Kept as a computed property over the template rather than folded into `AccessPolicy.canAuthor`
    /// so that reintroducing a free family stays a one-line change here (ADR 0144 D3).
    ///
    /// Nothing about Pro is persisted on an `Exercise`; access is computed **live** from `isPro`, so
    /// a lapsed trial re-locks every drill with no migration and re-unlocks instantly on subscribe
    /// (ADR 0112's "gate at read time", which 0144 keeps).
    var authoringTier: AccessTier {
        switch self {
        case .basic, .strumming, .warmup,
             .scales, .arpeggios, .chords, .strumChords, .picking, .legato,
             .fingerstyle, .rhythm, .earTraining, .theory, .freeform:
            return .pro
        }
    }
}

/// The single pure source of truth for "may this player do X, given their entitlement?"
///
/// **Since ADR 0144 the answer is always `isPro`.** Every function below collapses to it, and the two
/// free-taste allowlists are empty. The type is deliberately *not* deleted: every gate in the app
/// routes through here rather than testing `isPro` inline, so the entitlement line lives in exactly
/// one place, stays exhaustively unit-tested, and a future free line is a change to this file alone
/// (ADR 0144 D3). `isPro` is passed in — `AccessPolicy` never touches StoreKit or the `StoreManager`,
/// keeping it Foundation-only and pure.
///
/// The **authoring** / **running** distinction also survives for the same reason. ADR 0112 drew the
/// line differently for each (a free player could run a curated preset they couldn't edit); 0144
/// draws it in the same place for both, but the two questions remain separately askable.
///
/// Above these gates sits ADR 0144 D4's coarser wall — the four locked Home destinations and the
/// once-per-launch paywall. These calls are the **defence in depth** behind it, and are what re-lock
/// correctly the moment a trial lapses mid-session.
enum AccessPolicy {
    /// May the player **author** with `template` — create a new exercise from it, open the "draw your
    /// own" canvas, **or edit an existing exercise's shape/settings**? Pro, always (ADR 0144 D1).
    static func canAuthor(_ template: ExerciseTemplate, isPro: Bool) -> Bool {
        isPro || template.authoringTier == .free
    }

    /// May the player **run** an exercise of `template`? Pro, always (ADR 0144 D1).
    ///
    /// `isFreeTastePreset` is retained, defaulted, and currently always ineffective (`freeTasteSlugs`
    /// is empty). Keeping the parameter means the ~6 call sites that pass an exercise's provenance
    /// need no edit if a run-side allowance ever returns — see ADR 0144 D3.
    static func canRun(_ template: ExerciseTemplate,
                       isPro: Bool,
                       isFreeTastePreset: Bool = false) -> Bool {
        isPro || template.authoringTier == .free || isFreeTastePreset
    }

    /// **Empty since ADR 0144.** Formerly the permanent free taste — the exact seeded presets a free
    /// player could *run* even though their template was Pro to author.
    ///
    /// This is the **seam a free line would return through**: put slugs back here and the run gates
    /// re-open for exactly those presets, with no call-site change anywhere. Any slug added must match
    /// a `PracticePresets.Spec` slug, which is a frozen identifier (`Exercise.presetSlug` provenance).
    ///
    /// Note the seeded presets themselves are unchanged and still ship on first run — they are now
    /// **trial content** rather than a free taste (ADR 0144 D8).
    static let freeTasteSlugs: Set<String> = []

    /// Whether `slug` (an `Exercise.presetSlug`) is one of the free-taste presets. Always `false`
    /// while `freeTasteSlugs` is empty; `nil` (a user-authored drill) is never free taste.
    static func isFreeTaste(slug: String?) -> Bool {
        guard let slug else { return false }
        return freeTasteSlugs.contains(slug)
    }

    // MARK: - Routines

    /// May the player **author** routines at all — build a new one, edit an existing one, or accept a
    /// generated session from the planner / a collection / a song? Pro, always.
    static func canAuthorRoutine(isPro: Bool) -> Bool { isPro }

    /// May the player **open the routine editor** for this routine? Pro, always (ADR 0144 D1).
    ///
    /// ADR 0112's **demo exception** — a free player could open and rearrange the curated starter
    /// routine — is withdrawn along with the rest of the free line. The parameter survives as the
    /// seam (ADR 0144 D3) and is inert while `freeTasteRoutineSlugs` is empty.
    static func canEditRoutine(isPro: Bool, isFreeTasteRoutine: Bool = false) -> Bool {
        isPro || isFreeTasteRoutine
    }

    /// May the player **add blocks** to a routine (a unit or a rest)? Pro, always.
    static func canAddRoutineUnits(isPro: Bool) -> Bool { isPro }

    /// May the player **run** this routine? Pro, always (ADR 0144 D1).
    static func canRunRoutine(isPro: Bool, isFreeTasteRoutine: Bool = false) -> Bool {
        isPro || isFreeTasteRoutine
    }

    /// **Empty since ADR 0144.** Formerly the single curated starter routine ("Morning Routine") a
    /// free player could run forever. The routine-axis twin of `freeTasteSlugs`, and the same seam:
    /// a slug here re-opens `canRunRoutine` / `canEditRoutine` for that routine alone. Must match a
    /// `RoutinePresets` slug (`Routine.presetSlug` provenance).
    static let freeTasteRoutineSlugs: Set<String> = []

    /// Whether `slug` (a `Routine.presetSlug`) is the curated free-taste routine. Always `false` while
    /// `freeTasteRoutineSlugs` is empty; `nil` (a user-built routine) is never free taste.
    static func isFreeTasteRoutine(slug: String?) -> Bool {
        guard let slug else { return false }
        return freeTasteRoutineSlugs.contains(slug)
    }
}
