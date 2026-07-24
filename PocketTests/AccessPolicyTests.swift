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

    /// The taste is a *run* allowance only — it never grants authoring.
    func testFreeTastePresetDoesNotGrantAuthoring() {
        XCTAssertFalse(AccessPolicy.canAuthor(.scales, isPro: false))
        XCTAssertFalse(AccessPolicy.canAuthor(.legato, isPro: false))
    }
}
