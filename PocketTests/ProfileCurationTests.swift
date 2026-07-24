import XCTest
@testable import Pocket

/// Pure curation logic for the local artist profile (ADR 0113, Slice 2): the intake enums, their
/// consumer mappings (fresh-exercise tempo default, planner session length), and the primitive-backed
/// computed accessors on `Profile`. Property logic only — `Profile` objects are built **uninserted**
/// (no `ModelContext`), which is the safe shape for @Model property tests in the XCTest host
/// (swiftdata-insert-test-host-trap).
final class ProfileCurationTests: XCTestCase {

    // MARK: - Experience → default command tempo (consumer)

    func testExperienceDefaultTemposRiseWithLevel() {
        XCTAssertEqual(ArtistExperience.justStarting.defaultCommandTempo, 50)
        XCTAssertEqual(ArtistExperience.fewChords.defaultCommandTempo, 60)
        XCTAssertEqual(ArtistExperience.comfortable.defaultCommandTempo, 75)
        XCTAssertEqual(ArtistExperience.aWhile.defaultCommandTempo, 90)
    }

    func testExperienceTempoIsMonotonic() {
        let tempos = ArtistExperience.allCases.map(\.defaultCommandTempo)
        XCTAssertEqual(tempos, tempos.sorted(), "Later experience levels never start slower")
    }

    // MARK: - Minutes-per-day → session length (consumer)

    func testMinutesMapToSessionLength() {
        XCTAssertEqual(PracticeMinutes.short.preferredSessionLength, .quick)
        XCTAssertEqual(PracticeMinutes.medium.preferredSessionLength, .focused)
        XCTAssertEqual(PracticeMinutes.long.preferredSessionLength, .full)
        XCTAssertEqual(PracticeMinutes.varies.preferredSessionLength, .default)
    }

    // MARK: - Enum raw round-trips (SwiftData primitive backing)

    func testEnumRawValuesRoundTrip() {
        for value in ArtistExperience.allCases {
            XCTAssertEqual(ArtistExperience(rawValue: value.rawValue), value)
        }
        for value in MusicGenre.allCases {
            XCTAssertEqual(MusicGenre(rawValue: value.rawValue), value)
        }
        for value in MusicalDream.allCases {
            XCTAssertEqual(MusicalDream(rawValue: value.rawValue), value)
        }
        for value in PracticeMinutes.allCases {
            XCTAssertEqual(PracticeMinutes(rawValue: value.rawValue), value)
        }
    }

    func testDisplayNamesArePresent() {
        for value in ArtistExperience.allCases { XCTAssertFalse(value.displayName.isEmpty) }
        for value in MusicGenre.allCases { XCTAssertFalse(value.displayName.isEmpty) }
        for value in MusicalDream.allCases { XCTAssertFalse(value.displayName.isEmpty) }
        for value in PracticeMinutes.allCases { XCTAssertFalse(value.displayName.isEmpty) }
    }

    // MARK: - Profile computed accessors (primitive ↔ enum)

    func testProfileExperienceAccessorBacksRawValue() {
        let profile = Profile()
        XCTAssertNil(profile.experience)

        profile.experience = .comfortable
        XCTAssertEqual(profile.experienceRaw, MusicGenreRawFixture.comfortable)
        XCTAssertEqual(profile.experience, .comfortable)

        profile.experience = nil
        XCTAssertNil(profile.experienceRaw)
    }

    func testProfileGenresRoundTripThroughRawArray() {
        let profile = Profile()
        XCTAssertTrue(profile.genres.isEmpty)

        profile.genres = [.blues, .jazz]
        XCTAssertEqual(profile.genresRaw, ["blues", "jazz"])
        XCTAssertEqual(profile.genres, [.blues, .jazz])
    }

    func testProfileGenresDropUnrecognisedRawValues() {
        let profile = Profile()
        // Simulate a stored value from a future/renamed case — it decodes away, no crash.
        profile.genresRaw = ["blues", "flamenco", "pop"]
        XCTAssertEqual(profile.genres, [.blues, .pop])
    }

    func testProfileDreamAndMinutesAccessors() {
        let profile = Profile()
        profile.dream = .writeMusic
        profile.minutesPerDay = .long
        XCTAssertEqual(profile.dreamRaw, "writeMusic")
        XCTAssertEqual(profile.minutesPerDayRaw, "long")
        XCTAssertEqual(profile.dream, .writeMusic)
        XCTAssertEqual(profile.minutesPerDay, .long)
    }

    // MARK: - Preferred instrument (ADR 0116)

    func testPreferredInstrumentDefaultsToGuitarWhenUnset() {
        // Unlike the optional curation fields, this one always resolves — a fresh exercise always
        // needs an instrument, and an untouched / pre-0116 profile means guitar.
        let profile = Profile()
        XCTAssertNil(profile.preferredInstrumentRaw)
        XCTAssertEqual(profile.preferredInstrument, .guitar)
    }

    func testPreferredInstrumentRoundTripsAndFallsBack() {
        let profile = Profile()
        profile.preferredInstrument = .bass
        XCTAssertEqual(profile.preferredInstrumentRaw, "bass")
        XCTAssertEqual(profile.preferredInstrument, .bass)

        // A future/renamed instrument value decodes back to guitar rather than crashing.
        profile.preferredInstrumentRaw = "sitar"
        XCTAssertEqual(profile.preferredInstrument, .guitar)
    }
}

/// Small raw-value fixture kept out of the assertions above so the test reads as intent, not literals.
private enum MusicGenreRawFixture {
    static let comfortable = ArtistExperience.comfortable.rawValue
}
