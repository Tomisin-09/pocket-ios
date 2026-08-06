import XCTest
@testable import Pocket

/// The pure entitlement axis: `ExerciseTemplate.authoringTier` + `AccessPolicy`. No StoreKit, no
/// `@Model`, no UI.
///
/// **ADR 0144 inverted this file.** Under ADR 0112 most of these assertions proved that a free player
/// *could* do something — author from three free templates, run four curated presets, open and
/// rearrange one demo routine. The whole app is now Pro (the Toolkit, which contains no gates at all,
/// is the free surface), so they prove the opposite. What is pinned here is therefore:
///
/// 1. every gate answers plain `isPro`, for every input;
/// 2. **both free-taste allowlists are empty** — the seam is present but inert;
/// 3. the seam still *works*, so re-opening a free line stays the one-file change ADR 0144 D3
///    promises. Those tests pass a `true` provenance flag directly rather than through a slug.
final class AccessPolicyTests: XCTestCase {

    // MARK: - authoringTier

    func testEveryTemplateIsProToAuthor() {
        for template in ExerciseTemplate.allCases {
            XCTAssertEqual(template.authoringTier, .pro, "\(template) should be Pro to author")
        }
    }

    /// No free-tier family survives (ADR 0144 D1). `authoringTier`'s exhaustive `switch` means adding
    /// a template won't compile without a decision; this pins which way that decision has to go.
    func testNoTemplateIsFreeToAuthor() {
        XCTAssertTrue(ExerciseTemplate.allCases.allSatisfy { $0.authoringTier != .free })
    }

    // MARK: - canAuthor / canRun

    func testProUnlocksAuthoringAndRunningForEveryTemplate() {
        for template in ExerciseTemplate.allCases {
            XCTAssertTrue(AccessPolicy.canAuthor(template, isPro: true), "Pro should author \(template)")
            XCTAssertTrue(AccessPolicy.canRun(template, isPro: true), "Pro should run \(template)")
            XCTAssertTrue(AccessPolicy.canRun(template, isPro: true, isFreeTastePreset: true))
        }
    }

    func testWithoutProNothingAuthorsAndNothingRuns() {
        for template in ExerciseTemplate.allCases {
            XCTAssertFalse(AccessPolicy.canAuthor(template, isPro: false),
                           "\(template) must not author without Pro")
            XCTAssertFalse(AccessPolicy.canRun(template, isPro: false),
                           "\(template) must not run without Pro")
        }
    }

    /// The run gate fails **closed** when a caller omits provenance — the default that matters, since
    /// most call sites rely on it.
    func testRunDefaultsToLockedWithoutPro() {
        XCTAssertFalse(AccessPolicy.canRun(.scales, isPro: false))
    }

    // MARK: - The seam is inert, but intact (ADR 0144 D3)

    func testBothFreeTasteAllowlistsAreEmpty() {
        XCTAssertTrue(AccessPolicy.freeTasteSlugs.isEmpty)
        XCTAssertTrue(AccessPolicy.freeTasteRoutineSlugs.isEmpty)
    }

    /// Every slug the app actually stamps — including the ones that *used* to be free taste — now
    /// resolves to "not free taste".
    func testNoSeededSlugIsFreeTasteAnyMore() {
        for slug in ["a-minor-pentatonic", "pop-changes", "alternate-picking", "legato"] {
            XCTAssertFalse(AccessPolicy.isFreeTaste(slug: slug), "\(slug) is no longer free taste")
        }
        XCTAssertFalse(AccessPolicy.isFreeTaste(slug: nil))
        XCTAssertFalse(AccessPolicy.isFreeTasteRoutine(slug: RoutinePresets.freeTasteSlug))
        XCTAssertFalse(AccessPolicy.isFreeTasteRoutine(slug: nil))
    }

    /// The allowlist ↔ preset contract, moved here from `PracticePresetsTests` when ADR 0144 emptied
    /// it. Vacuous today, and deliberately kept: whatever is put back must name a preset that actually
    /// **ships and seeds on a fresh install**, or the allowance points at an exercise that isn't there.
    func testAnyFreeTasteSlugMustBeAShippedFirstRunPreset() {
        let shipped = Set(PracticePresets.allSpecs.map(\.slug))
        let firstRun = Set(PracticePresets.firstRunSlugs)
        for slug in AccessPolicy.freeTasteSlugs {
            XCTAssertTrue(shipped.contains(slug), "free-taste slug \(slug) has no shipped preset")
            XCTAssertTrue(firstRun.contains(slug), "free-taste \(slug) is never seeded")
        }
    }

    /// **The seam still works.** Passing the provenance flag directly re-opens the run allowance — so
    /// reintroducing a free line really is a matter of putting slugs back in the allowlists, with no
    /// call-site change. If this ever fails, the parameters have been quietly neutered and ADR 0144
    /// D3's promise is gone.
    func testProvenanceFlagStillOpensTheRunGates() {
        XCTAssertTrue(AccessPolicy.canRun(.scales, isPro: false, isFreeTastePreset: true))
        XCTAssertTrue(AccessPolicy.canRunRoutine(isPro: false, isFreeTasteRoutine: true))
        XCTAssertTrue(AccessPolicy.canEditRoutine(isPro: false, isFreeTasteRoutine: true))
    }

    // MARK: - Routines

    func testEveryRoutineGateAnswersIsPro() {
        XCTAssertTrue(AccessPolicy.canAuthorRoutine(isPro: true))
        XCTAssertFalse(AccessPolicy.canAuthorRoutine(isPro: false))
        XCTAssertTrue(AccessPolicy.canAddRoutineUnits(isPro: true))
        XCTAssertFalse(AccessPolicy.canAddRoutineUnits(isPro: false))
        XCTAssertTrue(AccessPolicy.canRunRoutine(isPro: true))
        XCTAssertTrue(AccessPolicy.canEditRoutine(isPro: true))
    }

    /// The demo exception is gone: without Pro there is no routine to run and none to open, whatever
    /// slug it carries (ADR 0144 D1).
    func testWithoutProNoRoutineRunsOrOpens() {
        XCTAssertFalse(AccessPolicy.canRunRoutine(isPro: false))
        XCTAssertFalse(AccessPolicy.canEditRoutine(isPro: false))
        XCTAssertFalse(AccessPolicy.canRunRoutine(
            isPro: false,
            isFreeTasteRoutine: AccessPolicy.isFreeTasteRoutine(slug: RoutinePresets.freeTasteSlug)))
    }

    /// The seeded starter routine still seeds first — it is trial content now (ADR 0144 D8), not a
    /// free taste, and its slug is still the frozen provenance identifier the seeder stamps.
    func testStarterRoutineSlugStillMatchesTheSeededSpec() {
        XCTAssertEqual(RoutinePresets.specs.first?.slug, RoutinePresets.freeTasteSlug)
    }
}
