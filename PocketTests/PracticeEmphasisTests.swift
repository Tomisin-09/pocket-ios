import XCTest
@testable import Pocket

/// The profile-driven emphasis mix (ADR 0113 Slice 3): `PracticeEmphasis` lifts a candidate's
/// priority when its skill/mode matches the declared genres/dream, and the `GenreSkillMap` /
/// `MusicalDream` tables it reads stay valid against the taxonomy. Pure logic — no `@Model` inserts.
final class PracticeEmphasisTests: XCTestCase {

    // MARK: - Neutral (skipped / absent profile)

    func testNeutralNeverChangesPriority() {
        let neutral = PracticeEmphasis.neutral
        // A skill known to be genre-mapped and a dream-mapped mode both still multiply by 1.0.
        XCTAssertEqual(neutral.multiplier(forSkillID: "scale.blues", mode: .loopDrill), 1.0)
        XCTAssertEqual(neutral.multiplier(forSkillID: "rep.learn-song", mode: .repertoire), 1.0)
    }

    func testEmptyGenresAndNilDreamEqualsNeutral() {
        let empty = PracticeEmphasis(genres: [], dream: nil)
        XCTAssertEqual(empty.multiplier(forSkillID: "scale.blues", mode: .loopDrill), 1.0)
    }

    // MARK: - Genre lift

    func testGenreLiftsOnlyItsMappedSkills() {
        let blues = PracticeEmphasis(genres: [.blues], dream: nil)
        // scale.blues is in the blues map; give it a mode the dream can't also lift so we isolate genre.
        XCTAssertEqual(blues.multiplier(forSkillID: "scale.blues", mode: .loopDrill),
                       PracticeEmphasis.genreLift, accuracy: 0.0001)
        // A skill outside the blues map is untouched.
        XCTAssertEqual(blues.multiplier(forSkillID: "pick.sweep", mode: .speedRamp), 1.0)
    }

    func testMultipleGenresUnionTheirSkills() {
        let mix = PracticeEmphasis(genres: [.blues, .metal], dream: nil)
        XCTAssertEqual(mix.multiplier(forSkillID: "scale.blues", mode: .loopDrill),
                       PracticeEmphasis.genreLift, accuracy: 0.0001, "from blues")
        XCTAssertEqual(mix.multiplier(forSkillID: "pick.sweep", mode: .speedRamp),
                       PracticeEmphasis.genreLift, accuracy: 0.0001, "from metal")
    }

    // MARK: - Dream lift (by mode)

    func testDreamLiftsItsModeOnly() {
        let getGood = PracticeEmphasis(genres: [], dream: .getGood)  // → .speedRamp
        // A skill not in any genre map, so only the dream can lift it.
        XCTAssertEqual(getGood.multiplier(forSkillID: "pick.string-skip", mode: .speedRamp),
                       PracticeEmphasis.dreamLift, accuracy: 0.0001)
        XCTAssertEqual(getGood.multiplier(forSkillID: "pick.string-skip", mode: .offGuitar), 1.0)
    }

    func testEveryDreamMapsToADistinctMode() {
        let modes = MusicalDream.allCases.map(\.emphasisedMode)
        XCTAssertEqual(Set(modes).count, MusicalDream.allCases.count,
                       "each dream tilts toward its own mode — no two collide")
    }

    // MARK: - Combination & cap

    func testGenreAndDreamCompoundButClampToCap() {
        // metal maps pick.sweep; getGood tilts .speedRamp → both lifts apply to a sweep-picking drill.
        let both = PracticeEmphasis(genres: [.metal], dream: .getGood)
        let raw = PracticeEmphasis.genreLift * PracticeEmphasis.dreamLift
        XCTAssertGreaterThan(raw, PracticeEmphasis.cap, "guard: the product would exceed the cap")
        XCTAssertEqual(both.multiplier(forSkillID: "pick.sweep", mode: .speedRamp),
                       PracticeEmphasis.cap, accuracy: 0.0001)
    }

    func testEmphasisNeverOutranksAnExplicitHighGoal() {
        // The whole calibration promise: a fully-emphasised Normal candidate stays below a High goal.
        XCTAssertLessThan(GoalPriority.normal.weight * PracticeEmphasis.cap,
                          GoalPriority.high.weight,
                          "taste tilt must never beat a stated High priority")
    }

    func testMultiplierIsAlwaysAtLeastOne() {
        let emphasis = PracticeEmphasis(genres: [.jazz], dream: .writeMusic)
        for skill in TechniqueTaxonomy.all {
            let value = emphasis.multiplier(forSkillID: skill.id, mode: skill.mode)
            XCTAssertGreaterThanOrEqual(value, 1.0, "emphasis lifts, never punishes (\(skill.id))")
            XCTAssertLessThanOrEqual(value, PracticeEmphasis.cap, "and never exceeds the cap")
        }
    }

    // MARK: - GenreSkillMap invariants

    func testEveryGenreMapsToAtLeastOneSkill() {
        for genre in MusicGenre.allCases {
            XCTAssertFalse(GenreSkillMap.skillIDs(for: genre).isEmpty,
                           "\(genre.rawValue) has no emphasised skills")
        }
    }

    func testEveryMappedSkillIsARealTaxonomyID() {
        for genre in MusicGenre.allCases {
            for skillID in GenreSkillMap.skillIDs(for: genre) {
                XCTAssertNotNil(TechniqueTaxonomy.info(skillID),
                                "\(genre.rawValue) → \(skillID) is not a taxonomy skill")
            }
        }
    }

    func testGenreSkillListsHaveNoDuplicates() {
        for genre in MusicGenre.allCases {
            let ids = GenreSkillMap.skillIDs(for: genre)
            XCTAssertEqual(ids.count, Set(ids).count, "\(genre.rawValue) repeats a skill")
        }
    }
}
