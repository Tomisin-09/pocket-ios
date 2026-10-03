import SwiftData
import XCTest
@testable import Pocket

/// **What you play** (ADR 0248): the intake's first question, and the one split the rest of the app reads
/// from it — a neck to draw drills on, or songs, loops and the metronome. Property logic runs on
/// uninserted `Profile`s; the writer, the seed and the archive need a real in-memory context.
final class PlayedInstrumentTests: XCTestCase {

    // MARK: - The answers

    /// Tomisin's order: guitar first, bass second, then the rest (2026-10-03).
    func testGuitarAndBassComeFirst() {
        XCTAssertEqual(Array(PlayedInstrument.allCases.prefix(2)), [.guitar, .bass])
        XCTAssertEqual(PlayedInstrument.allCases.last, .other, "Something else closes the list")
    }

    /// Only the two with a neck here keep the drills; ukulele has none yet (ADR 0116).
    func testOnlyGuitarAndBassHaveANeck() {
        let necked = PlayedInstrument.allCases.filter { !$0.leansOnSongs }
        XCTAssertEqual(necked, [.guitar, .bass])
        XCTAssertEqual(PlayedInstrument.guitar.fretboard, .guitar)
        XCTAssertEqual(PlayedInstrument.bass.fretboard, .bass)
        XCTAssertNil(PlayedInstrument.ukulele.fretboard)
    }

    /// The experience card follows the answer; a skipped answer asks about the guitar, as it always did.
    func testTheExperienceCardSpeaksToWhatTheyPlay() {
        XCTAssertEqual(ArtistExperience.fewChords.displayName, "Know a few chords")
        XCTAssertEqual(ArtistExperience.fewChords.displayName(for: nil), "Know a few chords")
        XCTAssertEqual(ArtistExperience.fewChords.displayName(for: .singing), "Know a few songs")
        XCTAssertEqual(ArtistExperience.fewChords.displayName(for: .bass), "Know a few lines")
        XCTAssertEqual(ArtistExperience.aWhile.displayName(for: .producing), "Been producing a while")
        XCTAssertEqual(ArtistExperience.aWhile.displayName(for: .drums), "Been playing a while")
        XCTAssertEqual(PlayedInstrument.singing.experienceSubject, "singing")
        XCTAssertEqual(PlayedInstrument.piano.experienceSubject, "the piano")
    }

    // MARK: - The intake's cards

    /// Six for a guitarist; five after *Just unwind*, or for anyone without a neck — their first run has
    /// no drills, so by ADR 0246 D4's own rule no goal would come to anything.
    func testTheGoalsCardIsForGuitarAndBass() {
        XCTAssertEqual(IntakeStep.steps(plays: nil, dream: nil),
                       [.plays, .experience, .genres, .dream, .goals, .minutes])
        XCTAssertEqual(IntakeStep.steps(plays: .bass, dream: .getGood).count, 6)
        XCTAssertFalse(IntakeStep.steps(plays: .guitar, dream: .unwind).contains(.goals))
        for plays in PlayedInstrument.allCases where plays.leansOnSongs {
            XCTAssertFalse(IntakeStep.steps(plays: plays, dream: .playSongs).contains(.goals), "\(plays)")
            XCTAssertFalse(IntakeGoalOffer.asksForGoals(after: .getGood, plays: plays), "\(plays)")
        }
    }

    /// *What do you play?* is first whatever the answers, so answering it can't move the player off it.
    func testWhatYouPlayIsAlwaysFirst() {
        for plays in [nil] + PlayedInstrument.allCases.map(Optional.some) {
            for dream in [nil] + MusicalDream.allCases.map(Optional.some) {
                XCTAssertEqual(IntakeStep.steps(plays: plays, dream: dream).first, .plays)
                XCTAssertEqual(IntakeStep.steps(plays: plays, dream: dream)[3], .dream,
                               "the dream must stay fourth, or answering it moves the player")
            }
        }
    }

    // MARK: - The profile

    func testPlaysRoundTripsAndAnUnknownValueReadsAsUnanswered() {
        let profile = Profile()
        XCTAssertNil(profile.plays)
        profile.plays = .piano
        XCTAssertEqual(profile.playsRaw, "piano")
        XCTAssertEqual(profile.plays, .piano)
        profile.playsRaw = "theremin"
        XCTAssertNil(profile.plays)
    }

    /// A profile from before the question shows the neck it chose — Bass stays Bass in Settings.
    func testAnOlderProfileReadsAsItsNeck() {
        let profile = Profile()
        XCTAssertEqual(profile.playsOrNeck, .guitar)
        profile.preferredInstrument = .bass
        XCTAssertEqual(profile.playsOrNeck, .bass)
        profile.plays = .singing
        XCTAssertEqual(profile.playsOrNeck, .singing)
    }

    /// A bassist's new drills open on the bass (what ADR 0116 meant the intake to do); a pianist leaves
    /// the neck where it was; neither touches the curation answers.
    func testSetPlaysSetsTheNeckOnlyWhenThereIsOne() throws {
        let context = try makeContext(for: Profile.self)
        Profile.setCuration(experience: .comfortable, genres: [.blues], dream: .writeMusic,
                            minutesPerDay: .long, in: context)

        Profile.setPlays(.bass, in: context)
        let profile = try XCTUnwrap(Profile.existing(in: context))
        XCTAssertEqual(profile.plays, .bass)
        XCTAssertEqual(profile.preferredInstrument, .bass)

        Profile.setPlays(.piano, in: context)
        XCTAssertEqual(profile.plays, .piano)
        XCTAssertEqual(profile.preferredInstrument, .bass, "a pianist's answer moved the neck")
        XCTAssertEqual(profile.experience, .comfortable, "the curation answers survive")
        XCTAssertEqual(profile.dream, .writeMusic)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Profile>()).count, 1)
    }

    // MARK: - The first run's seed

    /// Anyone without a neck gets no guitar drills, now or on any later launch.
    func testASongsLedAnswerSeedsNoDrillsAndNeverWill() throws {
        let context = try makeContext(for: Exercise.self)
        let defaults = try freshDefaults()

        PracticePresets.seedFirstRun(leansOnSongs: true, into: context, defaults: defaults)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).count, 0)
        PracticePresets.seedIfNeeded(into: context, defaults: defaults)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).count, 0,
                       "the next launch's seed put the guitar drills back")
    }

    func testGuitarOrBassSeedsTheFirstRunSet() throws {
        let context = try makeContext(for: Exercise.self)
        let defaults = try freshDefaults()

        PracticePresets.seedFirstRun(leansOnSongs: false, into: context, defaults: defaults)
        XCTAssertEqual(try context.fetch(FetchDescriptor<Exercise>()).count, PracticePresets.firstRunSpecs.count)
    }

    // MARK: - The archive

    /// What you play goes out in an export and comes back in a restore.
    @MainActor
    func testAnArchiveCarriesWhatYouPlay() throws {
        let profile = Profile()
        profile.plays = .producing
        let data = try JSONEncoder().encode(ArchiveBuilder.profileRecord(profile))
        let record = try JSONDecoder().decode(ProfileRecord.self, from: data)

        var landing = RestoredLibrary()
        ArchiveRestoreWriter.addProfile(record, existing: RestoreExistingKeys(), into: &landing)
        let restored = landing.profile?.plays
        XCTAssertEqual(restored, .producing)
    }

    /// An archive from before the field still opens: the whole file must not fail on one missing key.
    @MainActor
    func testAnOlderArchiveDecodesWithoutIt() throws {
        let profile = Profile()
        profile.preferredInstrument = .bass
        var json = try XCTUnwrap(JSONSerialization.jsonObject(
            with: try JSONEncoder().encode(ArchiveBuilder.profileRecord(profile))) as? [String: Any])
        json.removeValue(forKey: "playsRaw")
        let record = try JSONDecoder().decode(ProfileRecord.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(record.playsRaw)
        XCTAssertEqual(record.preferredInstrumentRaw, "bass")
    }

    // MARK: - Helpers

    private func makeContext(for type: any PersistentModel.Type) throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return ModelContext(try ModelContainer(for: type, configurations: config))
    }

    private func freshDefaults() throws -> UserDefaults {
        let name = "PlayedInstrumentTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        defaults.removePersistentDomain(forName: name)
        return defaults
    }
}
