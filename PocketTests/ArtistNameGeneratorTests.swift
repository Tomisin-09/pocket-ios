import XCTest
@testable import Pocket

/// The pure artist-name generator (ADR 0113 Slice 4): `seed → name` over curated pools, safe by
/// construction, deterministic-then-random. Pure logic — no `@Model`, no UI.
final class ArtistNameGeneratorTests: XCTestCase {

    /// A wide, fixed sweep of seeds for the "every name is well-formed/safe" property tests.
    private let sweep: [UInt64] = (0..<5_000).map { UInt64($0) &* 0x9E37_79B9_7F4A_7C15 }

    // MARK: - Determinism

    func testSameSeedAlwaysProducesSameName() {
        for seed in sweep.prefix(200) {
            XCTAssertEqual(ArtistNameGenerator.name(seed: seed),
                           ArtistNameGenerator.name(seed: seed))
        }
    }

    func testDifferentSeedsProduceVariety() {
        let names = Set(sweep.map(ArtistNameGenerator.name(seed:)))
        // Curated pools are large enough that a 5k sweep should surface plenty of distinct names.
        XCTAssertGreaterThan(names.count, 100, "the generator shouldn't collapse to a few names")
    }

    // MARK: - Well-formed & drawn only from the pools

    func testEveryNameIsNonEmptyAndTrimmed() {
        for seed in sweep {
            let name = ArtistNameGenerator.name(seed: seed)
            XCTAssertFalse(name.isEmpty)
            XCTAssertEqual(name, name.trimmingCharacters(in: .whitespaces), "no stray padding")
        }
    }

    func testEveryNameComposesFromCuratedPoolsOnly() {
        let singles = Set(ArtistNameGenerator.singles)
        let adjectives = Set(ArtistNameGenerator.adjectives)
        let nouns = Set(ArtistNameGenerator.nouns)
        for seed in sweep {
            let words = ArtistNameGenerator.name(seed: seed).split(separator: " ").map(String.init)
            switch words.count {
            case 1:
                XCTAssertTrue(singles.contains(words[0]) || words[0] == ArtistNameGenerator.fallbackName,
                              "\(words[0]) is not a curated single")
            case 2:
                XCTAssertTrue(adjectives.contains(words[0]), "\(words[0]) is not a curated adjective")
                XCTAssertTrue(nouns.contains(words[1]), "\(words[1]) is not a curated noun")
            default:
                XCTFail("names are one or two words, got \(words.count): \(words)")
            }
        }
    }

    func testBothPatternsAppearInASweep() {
        let names = sweep.map(ArtistNameGenerator.name(seed:))
        XCTAssertTrue(names.contains { !$0.contains(" ") }, "some single-word names appear")
        XCTAssertTrue(names.contains { $0.contains(" ") }, "some two-word names appear")
    }

    // MARK: - Safety

    func testNoGeneratedNameIsBlocked() {
        for seed in sweep {
            XCTAssertFalse(ArtistNameGenerator.isBlocked(ArtistNameGenerator.name(seed: seed)),
                           "seed \(seed) surfaced a blocked name")
        }
    }

    func testBlocklistMatchIsCaseAndSpaceInsensitive() {
        XCTAssertTrue(ArtistNameGenerator.isBlocked("KILL"))
        XCTAssertTrue(ArtistNameGenerator.isBlocked("Velvet Kill"))
        XCTAssertTrue(ArtistNameGenerator.isBlocked("ki ll".replacingOccurrences(of: " ", with: "")))
        XCTAssertFalse(ArtistNameGenerator.isBlocked("Velvet Wolf"))
    }

    func testPoolsAreCleanAndDisjointWhereItMatters() {
        // Adjective/noun disjoint so two-word names never double a word.
        XCTAssertTrue(Set(ArtistNameGenerator.adjectives).isDisjoint(with: Set(ArtistNameGenerator.nouns)))
        // No pool ships a blocked word itself.
        for pool in [ArtistNameGenerator.adjectives, ArtistNameGenerator.nouns, ArtistNameGenerator.singles] {
            for word in pool { XCTAssertFalse(ArtistNameGenerator.isBlocked(word), "\(word) is blocked") }
        }
        // No duplicates within a pool.
        for pool in [ArtistNameGenerator.adjectives, ArtistNameGenerator.nouns, ArtistNameGenerator.singles] {
            XCTAssertEqual(pool.count, Set(pool).count, "a pool repeats a word")
        }
    }

    // MARK: - Seeding from intake

    func testSeedIsDeterministicAndGenreOrderIndependent() {
        let one = ArtistNameGenerator.seed(experience: .comfortable, genres: [.blues, .rock], dream: .getGood)
        let two = ArtistNameGenerator.seed(experience: .comfortable, genres: [.rock, .blues], dream: .getGood)
        XCTAssertNotNil(one)
        XCTAssertEqual(one, two, "genre order must not change the seed")
    }

    func testSeedIsNilForAFullySkippedIntake() {
        XCTAssertNil(ArtistNameGenerator.seed(experience: nil, genres: [], dream: nil))
    }

    func testDifferentIntakeAnswersSeedDifferently() {
        let blues = ArtistNameGenerator.seed(experience: nil, genres: [.blues], dream: nil)
        let metal = ArtistNameGenerator.seed(experience: nil, genres: [.metal], dream: nil)
        XCTAssertNotEqual(blues, metal, "different declared taste ⇒ a different fated name")
    }
}
