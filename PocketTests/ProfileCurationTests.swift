import SwiftData
import XCTest
@testable import Pocket

/// Pure curation logic for the local artist profile (ADR 0113, Slice 2): the intake enums, their
/// consumer mappings (fresh-exercise tempo default, planner session length), and the primitive-backed
/// computed accessors on `Profile`. Property logic is tested on **uninserted** `Profile` objects (no
/// `ModelContext`), the safe shape for @Model property tests in the XCTest host.
///
/// The one exception is the **writer** section at the bottom, which needs a real in-memory container
/// because what it tests is the singleton fetch-or-create and the field independence between the two
/// writers — neither of which exists off a context.
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

    // MARK: - Writers (ADR 0116 — the Settings control's path to the store)

    /// `setPreferredInstrument` had **no caller at all** until the Settings row landed: the field, its
    /// accessor and this writer all existed while nothing in the app could reach them, so every
    /// consumer read the guitar fallback forever. Pins the writer end-to-end so the readers in
    /// `ExerciseLibraryView` / `MetronomeAutomatorPanel` have something real to read.
    func testSetPreferredInstrumentCreatesTheSingletonAndPersists() throws {
        let context = try makeContext()

        Profile.setPreferredInstrument(.bass, in: context)

        let rows = try context.fetch(FetchDescriptor<Profile>())
        XCTAssertEqual(rows.count, 1, "the writer creates the singleton row rather than needing one")
        XCTAssertEqual(rows.first?.preferredInstrument, .bass)
    }

    /// The two writers touch disjoint fields. `setCuration` overwrites its four as a *set* (a skipped
    /// question clears its field), so folding the instrument into it would let picking Bass wipe the
    /// answers — which is why Settings commits it separately.
    func testTheTwoWritersDoNotClobberEachOther() throws {
        let context = try makeContext()

        Profile.setCuration(experience: .comfortable, genres: [.blues], dream: .writeMusic,
                            minutesPerDay: .long, in: context)
        Profile.setPreferredInstrument(.bass, in: context)

        let profile = try XCTUnwrap(try context.fetch(FetchDescriptor<Profile>()).first)
        XCTAssertEqual(profile.preferredInstrument, .bass)
        XCTAssertEqual(profile.experience, .comfortable, "the curation answers survive an instrument change")
        XCTAssertEqual(profile.genres, [.blues])
        XCTAssertEqual(profile.dream, .writeMusic)
        XCTAssertEqual(profile.minutesPerDay, .long)

        // And the reverse order: editing "Your sound" must not reset the instrument to guitar.
        Profile.setCuration(experience: .aWhile, genres: [.jazz], dream: nil,
                            minutesPerDay: nil, in: context)
        XCTAssertEqual(profile.preferredInstrument, .bass)
    }

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: Profile.self, configurations: config))
    }
}

/// Small raw-value fixture kept out of the assertions above so the test reads as intent, not literals.
private enum MusicGenreRawFixture {
    static let comfortable = ArtistExperience.comfortable.rawValue
}
