import XCTest
@testable import Pocket

/// The pure entitlement axis (ADR 0112): `ExerciseTemplate.authoringTier` + `AccessPolicy`. No
/// StoreKit, no `@Model`, no UI — just the free/Pro rule, exhaustively pinned so a template added
/// later is a deliberate free-or-Pro decision, not an accidental free unlock.
final class AccessPolicyTests: XCTestCase {

    /// The exact free-authoring set per ADR 0112 ("free = basic/strumming/warm-up; Pro = the rest").
    private let freeToAuthor: Set<ExerciseTemplate> = [.basic, .strumming, .warmup]

    // MARK: - authoringTier

    func testFreeTemplatesAreFreeToAuthor() {
        for template in freeToAuthor {
            XCTAssertEqual(template.authoringTier, .free, "\(template) should be free to author")
        }
    }

    func testEveryOtherTemplateIsProToAuthor() {
        for template in ExerciseTemplate.allCases where !freeToAuthor.contains(template) {
            XCTAssertEqual(template.authoringTier, .pro, "\(template) should be Pro to author")
        }
    }

    /// Guards the split itself: exactly three free templates, so adding a case forces a conscious
    /// choice here rather than silently defaulting into one bucket.
    func testExactlyThreeFreeAuthoringTemplates() {
        let free = ExerciseTemplate.allCases.filter { $0.authoringTier == .free }
        XCTAssertEqual(Set(free), freeToAuthor)
        XCTAssertEqual(free.count, 3)
    }

    // MARK: - canAuthor

    func testProUnlocksAuthoringForEveryTemplate() {
        for template in ExerciseTemplate.allCases {
            XCTAssertTrue(AccessPolicy.canAuthor(template, isPro: true),
                          "Pro should author \(template)")
        }
    }

    func testFreeUserCanOnlyAuthorFreeTemplates() {
        for template in ExerciseTemplate.allCases {
            XCTAssertEqual(AccessPolicy.canAuthor(template, isPro: false),
                           freeToAuthor.contains(template),
                           "free authoring of \(template) should match its tier")
        }
    }

    // MARK: - canRun

    func testProUnlocksRunningForEveryTemplate() {
        for template in ExerciseTemplate.allCases {
            XCTAssertTrue(AccessPolicy.canRun(template, isPro: true),
                          "Pro should run \(template)")
            XCTAssertTrue(AccessPolicy.canRun(template, isPro: true, isFreeTastePreset: true))
        }
    }

    func testFreeUserRunsFreeTemplatesRegardlessOfPresetFlag() {
        for template in freeToAuthor {
            XCTAssertTrue(AccessPolicy.canRun(template, isPro: false))
            XCTAssertTrue(AccessPolicy.canRun(template, isPro: false, isFreeTastePreset: false))
        }
    }

    func testFreeUserCannotRunProTemplateByDefault() {
        for template in ExerciseTemplate.allCases where !freeToAuthor.contains(template) {
            XCTAssertFalse(AccessPolicy.canRun(template, isPro: false),
                           "a plain Pro-template exercise should run-lock for a free user: \(template)")
        }
    }

    func testFreeTastePresetRunsEvenOnAProTemplate() {
        // The curated taste: a free user runs these specific seeded presets even though the family
        // (scales, chords, picking, legato) is Pro to author.
        for template: ExerciseTemplate in [.scales, .chords, .picking, .legato] {
            XCTAssertTrue(AccessPolicy.canRun(template, isPro: false, isFreeTastePreset: true),
                          "a free-taste \(template) preset should run for a free user")
        }
    }

    /// The taste is a *run* allowance only — it never grants authoring, so a free player **cannot
    /// edit** a freebie (its template is Pro; editing routes through `canAuthor`, which has no taste
    /// parameter). This is the "can't edit the freebie" guarantee.
    func testFreeUserCannotEditAnyFreeTastePreset() {
        for template: ExerciseTemplate in [.scales, .chords, .picking, .legato] {
            XCTAssertFalse(AccessPolicy.canAuthor(template, isPro: false),
                           "a free user must not be able to edit a \(template) freebie")
        }
    }

    // MARK: - free-taste allowlist

    func testIsFreeTasteRecognisesTheFourFreebies() {
        for slug in ["a-minor-pentatonic", "pop-changes", "alternate-picking", "legato"] {
            XCTAssertTrue(AccessPolicy.isFreeTaste(slug: slug), "\(slug) should be free taste")
        }
    }

    func testIsFreeTasteRejectsNilAndOtherPresets() {
        XCTAssertFalse(AccessPolicy.isFreeTaste(slug: nil))          // a user-authored drill
        XCTAssertFalse(AccessPolicy.isFreeTaste(slug: "scale-runs")) // a seeded but non-taste preset
        XCTAssertFalse(AccessPolicy.isFreeTaste(slug: "a-minor-7-arpeggio"))
    }

    func testExactlyFourFreeTasteSlugs() {
        XCTAssertEqual(AccessPolicy.freeTasteSlugs.count, 4)
    }

    // MARK: - Routines (ADR 0112 — routines are Pro, one curated free taste)

    func testAuthoringARoutineAlwaysNeedsPro() {
        XCTAssertTrue(AccessPolicy.canAuthorRoutine(isPro: true))
        XCTAssertFalse(AccessPolicy.canAuthorRoutine(isPro: false))
    }

    func testProRunsAnyRoutine() {
        XCTAssertTrue(AccessPolicy.canRunRoutine(isPro: true))
        XCTAssertTrue(AccessPolicy.canRunRoutine(isPro: true, isFreeTasteRoutine: false))
    }

    func testFreePlayerRunsOnlyTheFreeTasteRoutine() {
        XCTAssertTrue(AccessPolicy.canRunRoutine(isPro: false, isFreeTasteRoutine: true))
        XCTAssertFalse(AccessPolicy.canRunRoutine(isPro: false, isFreeTasteRoutine: false))
    }

    /// The default matters: a caller that forgets to pass provenance must fail **closed**, not open.
    func testRunRoutineDefaultsToLockedForAFreePlayer() {
        XCTAssertFalse(AccessPolicy.canRunRoutine(isPro: false))
    }

    func testIsFreeTasteRoutineRecognisesOnlyMorningWarmUp() {
        XCTAssertTrue(AccessPolicy.isFreeTasteRoutine(slug: "morning-warm-up"))
        XCTAssertFalse(AccessPolicy.isFreeTasteRoutine(slug: "picking-builder"))
        XCTAssertFalse(AccessPolicy.isFreeTasteRoutine(slug: "rhythm-and-changes"))
        XCTAssertFalse(AccessPolicy.isFreeTasteRoutine(slug: nil))   // a user-built routine
    }

    func testExactlyOneFreeTasteRoutine() {
        XCTAssertEqual(AccessPolicy.freeTasteRoutineSlugs.count, 1)
    }

    /// The slug the policy allows must be the one the seeder actually stamps — otherwise the free
    /// routine silently Pro-locks. Pins the two constants together.
    func testFreeTasteRoutineSlugMatchesTheSeededSpec() {
        XCTAssertTrue(AccessPolicy.freeTasteRoutineSlugs.contains(RoutinePresets.freeTasteSlug))
        XCTAssertEqual(RoutinePresets.specs.first?.slug, RoutinePresets.freeTasteSlug)
    }
}
