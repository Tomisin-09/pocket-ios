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
        case .scales, .arpeggios, .chords, .strumChords, .picking, .legato,
             .fingerstyle, .rhythm, .earTraining, .theory:
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
}
