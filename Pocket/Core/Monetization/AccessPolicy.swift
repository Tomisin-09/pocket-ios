import Foundation

/// The **entitlement tier** a capability belongs to (ADR 0112). Free capabilities are always
/// available; Pro capabilities require an active Red Moon Pro entitlement (`isPro`). Deliberately a
/// two-case value with no associated data — the *mechanism* that resolves `isPro` (StoreKit 2, a
/// `StoreManager`) lives elsewhere; this axis is pure, Foundation-only, and unit-testable per the
/// "pure logic stays pure" rule (AGENTS.md).
enum AccessTier: Equatable {
    case free
    case pro
}

extension ExerciseTemplate {
    /// Whether **authoring** from this template is free or requires Red Moon Pro (ADR 0112).
    ///
    /// Free = the play-along basics a new player starts with: **Basic**, **Strumming**, **Warm-up**.
    /// Pro = the structured technique catalog — scales (modes/positions/CAGED), chords (movable +
    /// custom placer), arpeggios, picking, legato, and the rest (the deep IP of ADRs 0083–0091,
    /// 0101–0109, which costs nothing at the margin so unlimited access is safe to sell flat).
    ///
    /// This axis governs **creation** — making a new exercise from the template and the "draw your
    /// own" fretboard canvas. It does **not** govern *running* a seeded free-taste preset (the
    /// low-E pentatonic box, an open-chord set, a picking warm-up, legato): a free user can *run*
    /// those even though the template is Pro to author. That run-side allowance is a separate
    /// provenance signal the caller supplies to `AccessPolicy.canRun` — see `isFreeTastePreset`.
    ///
    /// Nothing about Pro is persisted on an `Exercise`; access is computed **live** from `isPro`, so
    /// a lapsed trial re-locks Pro-authored drills with no migration and re-unlocks instantly on
    /// subscribe (ADR 0112, "gate at read time").
    var authoringTier: AccessTier {
        switch self {
        case .basic, .strumming, .warmup:
            return .free
        // **Freeform** is Pro to author (ADR 0136 F7) and free to run, the same line every template
        // sits on — and it is a strong Pro argument in its own right: your whole practice lives here,
        // not only the parts we modelled.
        case .scales, .arpeggios, .chords, .strumChords, .picking, .legato,
             .fingerstyle, .rhythm, .earTraining, .theory, .freeform:
            return .pro
        }
    }
}

/// The single pure source of truth for "may this player do X, given their entitlement?" (ADR 0112).
///
/// Every gate in the app routes through these functions rather than testing `isPro` inline, so the
/// free/Pro line lives in exactly one place and is exhaustively unit-tested. `isPro` is passed in —
/// `AccessPolicy` never touches StoreKit or the `StoreManager`, keeping it Foundation-only and pure.
///
/// Two distinct questions, deliberately separate because the ADR draws the line differently for each:
/// - **Authoring** (`canAuthor`) is purely template-tier: creating any Pro-template exercise, or the
///   "draw your own" canvas, needs Pro.
/// - **Running** (`canRun`) is more permissive: a free player may run a free-template exercise *or* a
///   curated free-taste preset even from a Pro family — the "taste" that hooks conversion. Whether a
///   given exercise is one of those presets is provenance the caller resolves (Slice 2's preset
///   marker); `AccessPolicy` only combines it with the tier and `isPro`.
enum AccessPolicy {
    /// May the player **author** with `template` — create a new exercise from it, open the "draw your
    /// own" canvas, **or edit an existing exercise's shape/settings**? Pro unlocks everything;
    /// otherwise only free-tier templates.
    ///
    /// Editing routes through here too (not `canRun`), and `canAuthor` deliberately has **no**
    /// free-taste parameter — so a free player can *run* the seeded pentatonic/open-chord/picking/
    /// legato freebie but **cannot edit it** (its template is Pro; editing is authoring). Tapping
    /// "edit" on a freebie hits the paywall while "practice" runs it.
    static func canAuthor(_ template: ExerciseTemplate, isPro: Bool) -> Bool {
        isPro || template.authoringTier == .free
    }

    /// May the player **run** an exercise of `template`? Pro unlocks everything; a free player may
    /// still run any free-tier template, and any exercise flagged `isFreeTastePreset` (a curated
    /// seeded preset from the permanent free taste, ADR 0112) even when its template is Pro.
    ///
    /// `isFreeTastePreset` defaults to `false`, so a plain user-authored Pro exercise (e.g. one made
    /// on trial and then lapsed) run-locks correctly — only the seeded taste is exempt.
    static func canRun(_ template: ExerciseTemplate,
                       isPro: Bool,
                       isFreeTastePreset: Bool = false) -> Bool {
        isPro || template.authoringTier == .free || isFreeTastePreset
    }

    /// The **permanent free taste** (ADR 0112): the exact seeded presets a free player may *run*
    /// even though their template is Pro to author — the low-E pentatonic box, the open-chord
    /// turnaround, the picking warm-up, and legato. A **run** allowance only; it never grants
    /// authoring. Presets on a *free* template (the warm-ups, all strumming) don't appear here — they
    /// run free by tier already. These slugs are **frozen identifiers** (they match `presetSlug`
    /// provenance stamped by the seeder), so renaming a `PracticePresets.Spec` must keep its slug.
    static let freeTasteSlugs: Set<String> = [
        "a-minor-pentatonic",   // the low-E minor-pentatonic box (scales)
        "pop-changes",          // the open-chord set, G·D·Em·C (chords)
        "alternate-picking",    // the picking warm-up (picking)
        "legato"                // hammer-ons / pull-offs (legato)
    ]

    /// Whether `slug` (an `Exercise.presetSlug`) is one of the free-taste presets. `nil` (a
    /// user-authored drill) is never free taste. The convenience the run-gate sites call with an
    /// exercise's provenance.
    static func isFreeTaste(slug: String?) -> Bool {
        guard let slug else { return false }
        return freeTasteSlugs.contains(slug)
    }

    // MARK: - Routines

    /// May the player **author** routines at all — build a new one, edit an existing one, or accept a
    /// generated session from the planner / a collection / a song (ADR 0112)? **Routines are Pro**,
    /// full stop.
    ///
    /// This replaced an earlier "one free manual routine" allowance, which needed a count, a rule for
    /// *which* routine was the free one, and an answer for what happens to the other nine when a trial
    /// lapses. A flat rule needs none of that. Note there is no free-tier escape hatch here (unlike
    /// `canAuthor`, where free templates exist) — a routine has no template axis of its own; it
    /// inherits from the units it strings together, and composing *is* the authoring act.
    static func canAuthorRoutine(isPro: Bool) -> Bool { isPro }

    /// May the player **open the routine editor** for this routine? Pro unlocks everything; a free
    /// player may open exactly the curated free-taste routine — the **demo exception**.
    ///
    /// Viewing and rearranging the demo is deliberately *more* than the exercise freebies allow
    /// (there, editing is flatly Pro). The reasoning differs: an exercise's editor authors new
    /// *content*, while reordering a fixed set of blocks authors nothing — it only shows what a
    /// routine is for. Adding blocks is the authoring act, and that stays Pro via
    /// `canAddRoutineUnits`, which is also what keeps the free routine's contents ours and therefore
    /// free of Pro drills.
    static func canEditRoutine(isPro: Bool, isFreeTasteRoutine: Bool = false) -> Bool {
        isPro || isFreeTasteRoutine
    }

    /// May the player **add blocks** to a routine (a unit or a rest)? Pro, always — including inside
    /// the free demo, where reordering is allowed but adding is not. This is the seam that keeps the
    /// demo exception from reopening the routine bypass: a free player editing the demo can shuffle
    /// our curated blocks but can never introduce a Pro drill to run.
    static func canAddRoutineUnits(isPro: Bool) -> Bool { isPro }

    /// May the player **run** this routine? Pro unlocks everything; a free player may run exactly the
    /// curated free-taste routine (`isFreeTasteRoutine`) and nothing else.
    ///
    /// The narrow run allowance is what closes the **routine bypass**: because a free player can only
    /// ever play a routine we curated — one whose blocks are all free-tier or free-taste by
    /// construction — there is no way to smuggle a Pro drill into a routine and run it there, which
    /// the per-row library gate alone could not prevent.
    static func canRunRoutine(isPro: Bool, isFreeTasteRoutine: Bool = false) -> Bool {
        isPro || isFreeTasteRoutine
    }

    /// The **permanent free taste** on the routine axis (ADR 0112): the single curated starter routine
    /// a free player may *run* forever — Morning Routine, whose every block is a free-tier template or
    /// a free-taste exercise slug. A **run** allowance only; it never grants authoring, so a free
    /// player can practise it but not edit it (the same run-not-author line the exercise freebies
    /// draw). A frozen identifier matching the `presetSlug` the seeder stamps.
    static let freeTasteRoutineSlugs: Set<String> = [
        "morning-warm-up"       // warm-ups + picking + the pentatonic box (see `RoutinePresets`)
    ]

    /// Whether `slug` (a `Routine.presetSlug`) is the curated free-taste routine. `nil` (a user-built
    /// routine) is never free taste.
    static func isFreeTasteRoutine(slug: String?) -> Bool {
        guard let slug else { return false }
        return freeTasteRoutineSlugs.contains(slug)
    }
}
