import XCTest
@testable import Pocket

/// What a drill and a loop work on, and the skills the player made, **on the wire** (ADR 0216 D2/D7):
/// what an archive carries, what an archive written before 0216 does, how a restore folds a skill the
/// library already has, and what the two sharing doors let across.
final class CustomSkillArchiveTests: XCTestCase {

    private let looping = CustomSkillRecord(uid: UUID(), name: "Live looping",
                                            info: "Layering parts with a looper pedal.",
                                            dateAdded: ArchiveFixture.date)
    private var loopingID: String { SkillAssociation.customID(looping.uid) }

    private func archive(exerciseSkills: [String]?, loopSkills: [String]?,
                         customSkills: [CustomSkillRecord]?,
                         goalSkills: [String] = ["pick.alternate"]) -> PracticeArchive {
        var drill = ArchiveFixture.exercise(uid: UUID())
        drill.skillIDs = exerciseSkills
        var loop = ArchiveFixture.loop(uid: UUID())
        loop.skillIDs = loopSkills
        let goal = GoalRecord(uid: UUID(), title: "Loop live", weight: 1, skillIDs: goalSkills,
                              targetSongID: nil, isMet: false, dateAdded: ArchiveFixture.date)
        return PracticeArchive(exportedAt: ArchiveFixture.date,
                               appVersion: "1.3",
                               includesTakeAudio: false,
                               songs: [ArchiveFixture.song(sourceID: "song-1", loops: [loop])],
                               exercises: [drill],
                               goals: [goal],
                               customSkills: customSkills)
    }

    // MARK: - Round trip

    func testSkillsAndCustomSkillsSurviveAnEncodeAndDecode() throws {
        let written = archive(exerciseSkills: ["pick.alternate", loopingID], loopSkills: ["fret.bend"],
                              customSkills: [looping])
        let read = try ArchiveBuilder.decode(ArchiveBuilder.encode(written))
        XCTAssertEqual(read.exercises.first?.skillIDs, ["pick.alternate", loopingID])
        XCTAssertEqual(read.songs.first?.loops.first?.skillIDs, ["fret.bend"])
        XCTAssertEqual(read.customSkills, [looping], "the description behind its ⓘ travels too")
    }

    /// **The reason every field is `Optional`** — see `FolderArchiveTests` for the long version. An
    /// archive from 1.3 has none of these keys, and one missing non-optional key fails the whole file.
    func testAnArchiveWrittenBeforeSkillsExistedStillDecodes() throws {
        let written = archive(exerciseSkills: ["pick.alternate"], loopSkills: ["fret.bend"],
                              customSkills: [looping])
        let stripped = try strippingKeys(["skillIDs", "customSkills"], from: ArchiveBuilder.encode(written),
                                         keepingGoals: true)
        let read = try ArchiveBuilder.decode(stripped)
        XCTAssertNil(read.exercises.first?.skillIDs)
        XCTAssertNil(read.songs.first?.loops.first?.skillIDs)
        XCTAssertNil(read.customSkills)
        XCTAssertEqual(read.exercises.first?.name, "Spider walk", "one missing key took nothing else with it")
        XCTAssertEqual(read.goals.first?.skillIDs, ["pick.alternate"], "goal skills predate 0216 and stay")
    }

    // MARK: - Restore

    @MainActor
    func testAnArchiveWithoutSkillsRestoresDrillsThatFollowTheirType() {
        let landing = ArchiveRestoreWriter.materialize(
            archive(exerciseSkills: nil, loopSkills: nil, customSkills: nil), existing: RestoreExistingKeys())
        XCTAssertEqual(landing.exercises.first?.skillIDs, [])
        XCTAssertEqual(landing.songs.first?.loops.first?.skillIDs, [])
        XCTAssertTrue(landing.customSkills.isEmpty)
    }

    @MainActor
    func testRestoreLandsACustomSkillWithItsDescriptionAndTheIDsThatNameIt() throws {
        let landing = ArchiveRestoreWriter.materialize(
            archive(exerciseSkills: [loopingID], loopSkills: [loopingID], customSkills: [looping],
                    goalSkills: [loopingID]),
            existing: RestoreExistingKeys())
        let skill = try XCTUnwrap(landing.customSkills.first)
        XCTAssertEqual(skill.uid, looping.uid, "preserved, like every restored row's uid")
        XCTAssertEqual(skill.info, looping.info)
        XCTAssertEqual(landing.exercises.first?.skillIDs, [loopingID])
        XCTAssertEqual(landing.songs.first?.loops.first?.skillIDs, [loopingID])
        XCTAssertEqual(landing.goals.first?.skillIDs, [loopingID])
    }

    /// **A same-named skill folds onto the one already here.** Two *Live looping* rows would be one
    /// skill split across two ids, each scheduling half of what it should.
    @MainActor
    func testASameNamedSkillFoldsOntoTheOneTheLibraryHasAndEverythingIsRenamed() {
        let mine = SkillAssociation.customID(UUID())
        var resolver = RestoreResolver()
        resolver.customSkillIDsByName[CustomSkill.foldedName("live  LOOPING")] = mine
        let landing = ArchiveRestoreWriter.materialize(
            archive(exerciseSkills: ["pick.alternate", loopingID], loopSkills: [loopingID],
                    customSkills: [looping], goalSkills: [loopingID, mine]),
            existing: RestoreExistingKeys(), resolver: resolver)
        XCTAssertTrue(landing.customSkills.isEmpty, "no second row")
        XCTAssertEqual(landing.exercises.first?.skillIDs, ["pick.alternate", mine])
        XCTAssertEqual(landing.songs.first?.loops.first?.skillIDs, [mine])
        XCTAssertEqual(landing.goals.first?.skillIDs, [mine], "the fold's repeat is counted once")
    }

    @MainActor
    func testASkillWhoseUIDIsAlreadyHereIsNotRebuilt() {
        var resolver = RestoreResolver()
        resolver.existingCustomSkillUIDs = [looping.uid]
        let landing = ArchiveRestoreWriter.materialize(
            archive(exerciseSkills: [loopingID], loopSkills: nil, customSkills: [looping]),
            existing: RestoreExistingKeys(), resolver: resolver)
        XCTAssertTrue(landing.customSkills.isEmpty, "nothing is overwritten (ADR 0188 D6)")
        XCTAssertEqual(landing.exercises.first?.skillIDs, [loopingID])
    }

    @MainActor
    func testCustomSkillsDoNotCountAsRestoredRows() {
        let with = ArchiveRestoreWriter.materialize(
            archive(exerciseSkills: nil, loopSkills: nil, customSkills: [looping]), existing: RestoreExistingKeys())
        let without = ArchiveRestoreWriter.materialize(
            archive(exerciseSkills: nil, loopSkills: nil, customSkills: nil), existing: RestoreExistingKeys())
        XCTAssertEqual(with.rowCount, without.rowCount, "the preview promised library items, not vocabulary")
    }

    // MARK: - Sharing

    @MainActor
    func testASharedDrillCarriesTaxonomySkillsAndNotTheSendersOwn() {
        let exercise = Exercise(name: "Loop pedal warm-up")
        exercise.skillIDs = ["rhythm.timing", loopingID]
        XCTAssertEqual(SharedPracticeBuilder.shareable(exercise).skillIDs, ["rhythm.timing"])
    }

    @MainActor
    func testAReceivedDrillDropsCustomIDsEvenIfTheSenderDidnt() {
        var record = ArchiveFixture.exercise(uid: UUID())
        record.skillIDs = ["rhythm.timing", loopingID]
        XCTAssertEqual(ReceivedRoutineBuilder.exercise(from: record).skillIDs, ["rhythm.timing"])
        record.skillIDs = [loopingID]
        XCTAssertEqual(ReceivedRoutineBuilder.exercise(from: record).skillIDs, [],
                       "left with nothing, the drill follows its type")
    }

    // MARK: - Copies and undo

    func testADuplicateWorksOnTheSameSkills() {
        let exercise = Exercise(name: "Spider walk")
        exercise.skillIDs = ["fret.dexterity", loopingID]
        XCTAssertEqual(exercise.duplicated(named: "Spider walk copy").skillIDs, ["fret.dexterity", loopingID])
    }

    func testUndoingALoopEditRestoresItsSkills() {
        let loop = Loop(name: "Turnaround", start: 0.2, end: 0.4, speed: 1, repeats: 4)
        loop.skillIDs = ["fret.bend"]
        let before = LoopEditSnapshot(loop)
        loop.skillIDs = ["fret.bend", "fret.vibrato"]
        XCTAssertNotEqual(LoopEditSnapshot(loop), before, "a skills edit is a change Done reports")
        before.restore(to: loop)
        XCTAssertEqual(loop.skillIDs, ["fret.bend"])
    }

    // MARK: - Helpers

    /// Removes every occurrence of the named keys from encoded JSON — except inside `goals`, whose
    /// `skillIDs` long predate 0216 and so were never absent from any archive.
    private func strippingKeys(_ keys: Set<String>, from data: Data, keepingGoals: Bool) throws -> Data {
        func strip(_ value: Any, inGoal: Bool) -> Any {
            if let object = value as? [String: Any] {
                return object.reduce(into: [String: Any]()) { result, pair in
                    guard inGoal || !keys.contains(pair.key) else { return }
                    result[pair.key] = strip(pair.value, inGoal: inGoal || (keepingGoals && pair.key == "goals"))
                }
            }
            if let array = value as? [Any] { return array.map { strip($0, inGoal: inGoal) } }
            return value
        }
        let json = try JSONSerialization.jsonObject(with: data)
        return try JSONSerialization.data(withJSONObject: strip(json, inGoal: false))
    }
}
