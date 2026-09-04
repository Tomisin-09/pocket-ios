import XCTest
@testable import Pocket

/// What a restored row **points at**, and what comes back beside it (ADR 0188 S3, D1/D7).
///
/// The other half of `ArchiveRestoreHydrationTests`, split off when the two together outgrew
/// SwiftLint's type-body limit. That file argues about identity and about which of the sender's — or
/// rather the player's own — history crosses; this one argues about resolution: what a block, a
/// journal entry or a take ends up joined to, which files travel with them, and the two things an
/// archive cannot bring back.
///
/// Same contract as its sibling: everything is asserted on the **uninserted** graph `materialize`
/// returns, because inserting a full object graph in this host traps (`docs/swiftdata-gotchas.md`).
@MainActor
final class ArchiveRestoreResolutionTests: XCTestCase {

    private typealias Fixture = ArchiveFixture

    private func archive(_ build: (inout PracticeArchive) -> Void) -> PracticeArchive {
        var archive = PracticeArchive(exportedAt: Fixture.date, appVersion: "1.2 (5)", includesTakeAudio: true)
        build(&archive)
        return archive
    }

    private func landed(_ archive: PracticeArchive,
                        existing: RestoreExistingKeys = RestoreExistingKeys()) -> RestoredLibrary {
        ArchiveRestoreWriter.materialize(archive, existing: existing)
    }

    // MARK: - Resolution

    /// A block must point at the drill that came back with it.
    func testABlockResolvesTheDrillFromTheSameArchive() {
        let exerciseUID = UUID()
        let landing = landed(archive {
            $0.exercises = [Fixture.exercise(uid: exerciseUID)]
            $0.routines = [Fixture.routine(uid: UUID(),
                                           items: [Fixture.block(order: 0, exerciseUID: exerciseUID)])]
        })
        XCTAssertIdentical(landing.routines.first?.items.first?.exercise, landing.exercises.first)
    }

    /// And at one the library already had. Resolving to nothing would fabricate an orphan out of a link
    /// the archive recorded perfectly well; building a copy would duplicate a drill the player still
    /// has.
    func testABlockResolvesADrillTheLibraryAlreadyHeld() {
        let exerciseUID = UUID()
        let held = Exercise(name: "Already here")
        held.uid = exerciseUID
        var resolver = RestoreResolver()
        resolver.exercises[exerciseUID] = held
        var existing = RestoreExistingKeys()
        existing.exerciseUIDs = [exerciseUID]

        let landing = ArchiveRestoreWriter.materialize(
            archive {
                $0.exercises = [Fixture.exercise(uid: exerciseUID)]
                $0.routines = [Fixture.routine(uid: UUID(),
                                               items: [Fixture.block(order: 0, exerciseUID: exerciseUID)])]
            },
            existing: existing, resolver: resolver)

        XCTAssertTrue(landing.exercises.isEmpty, "the drill is skipped, not rebuilt")
        XCTAssertIdentical(landing.routines.first?.items.first?.exercise, held)
    }

    /// A block whose unit is nowhere lands as the orphan the app already draws, **named** — the
    /// additive `orphanLabel` the S2 follow-up added, and, as that slice predicted, the only label
    /// source this door has.
    func testABlockThatResolvesNothingLandsAsANamedOrphan() {
        let landing = landed(archive {
            $0.routines = [Fixture.routine(uid: UUID(),
                                           items: [Fixture.block(order: 0, loopUID: UUID(),
                                                                 orphanLabel: "Turnaround")])]
        })
        let block = try? XCTUnwrap(landing.routines.first?.items.first)

        XCTAssertNil(block?.exercise)
        XCTAssertNil(block?.loop)
        XCTAssertEqual(block?.orphanLabel, "Turnaround")
    }

    /// A label on a block that *did* resolve would be a fact about it that is not true.
    func testABlockThatResolvesIsNotGivenAnOrphanLabel() {
        let exerciseUID = UUID()
        let landing = landed(archive {
            $0.exercises = [Fixture.exercise(uid: exerciseUID)]
            $0.routines = [Fixture.routine(uid: UUID(),
                                           items: [Fixture.block(order: 0, exerciseUID: exerciseUID,
                                                                 orphanLabel: "Should not stick")])]
        })
        XCTAssertNil(landing.routines.first?.items.first?.orphanLabel)
    }

    /// S2 renumbers a received routine from zero, because a stranger's file may carry drift. A restore
    /// must not: these are the player's own numbers, and rewriting them means an archive cannot
    /// reproduce the library it was taken from.
    func testBlockOrderIsPreservedRatherThanRenumbered() {
        let landing = landed(archive {
            $0.routines = [Fixture.routine(uid: UUID(), items: [Fixture.block(order: 7),
                                                                Fixture.block(order: 3)])]
        })
        XCTAssertEqual(landing.routines.first?.items.map(\.order), [3, 7],
                       "sorted into play order, and keeping the numbers the file gave them")
    }

    // MARK: - Journal and takes

    /// The two owner shapes `JournalEntry` keeps, and why resolving the wrong one would matter:
    /// `routineUID` is a loose id so deleting a routine cannot delete a reflection about it.
    func testAJournalEntryKeepsALooseRoutineIDAndAResolvedUnit() {
        let exerciseUID = UUID()
        let routineUID = UUID()
        let landing = landed(archive {
            $0.exercises = [Fixture.exercise(uid: exerciseUID)]
            $0.journal = [Fixture.journalEntry(uid: UUID(), exerciseUID: exerciseUID, routineUID: routineUID)]
        })
        let entry = try? XCTUnwrap(landing.journal.first)

        XCTAssertIdentical(entry?.exercise, landing.exercises.first)
        XCTAssertEqual(entry?.routineUID, routineUID, "a loose id, not resolved into a relationship")
        XCTAssertEqual(entry?.routineNameAtEntry, "Morning warm-up")
    }

    func testAJournalEntryWhoseUnitIsGoneLandsAsAnOrphanRatherThanBeingDropped() {
        let landing = landed(archive { $0.journal = [Fixture.journalEntry(uid: UUID(), loopUID: UUID())] })
        let entry = try? XCTUnwrap(landing.journal.first)

        XCTAssertNil(entry?.loop)
        XCTAssertEqual(entry?.text, "Cleaner at 80.", "the words survive the unit")
    }

    /// The row lands whether or not the audio is in the zip: refusing it would throw away the writing
    /// to punish the absence of the recording.
    func testATakeLandsWithItsMomentsEvenWithNoAudioInTheArchive() throws {
        let landing = landed(archive { $0.takes = [Fixture.take(uid: UUID(), fileName: "gone.m4a")] })
        let (take, moments) = try XCTUnwrap(landing.takes.first)

        XCTAssertEqual(take.fileName, "gone.m4a")
        XCTAssertEqual(take.note, "Rushed the turnaround.")
        XCTAssertEqual(moments.map(\.text), ["here"])
        XCTAssertTrue(landing.takeAudio.isEmpty)
    }

    // MARK: - Files

    /// Only the files the landing rows name. An archive carries its whole library's audio; a restore
    /// into a populated one may be adding a fraction of it, and the rest would land in `Recordings/`
    /// with no row pointing at them — which is what ADR 0182's sweep deletes.
    func testOnlyAudioForTakesThatAreLandingIsCarried() {
        let landingUID = UUID()
        let heldUID = UUID()
        var existing = RestoreExistingKeys()
        existing.takeUIDs = [heldUID]

        let entry = ZipEntry(path: "takes/held.m4a", uncompressedSize: 1,
                             compressedSize: 1, method: 0, crc32: 0, localHeaderOffset: 0)
        let landing = ArchiveRestoreWriter.materialize(
            archive {
                $0.takes = [Fixture.take(uid: landingUID, fileName: "new.m4a"),
                            Fixture.take(uid: heldUID, fileName: "held.m4a")]
            },
            takeAudio: ["new.m4a": entry, "held.m4a": entry],
            existing: existing)

        XCTAssertEqual(Set(landing.takeAudio.keys), ["new.m4a"])
    }

    func testOnlyPicturesTheLandingRowsPointAtAreCarried() {
        let entry = ZipEntry(path: "references/x.jpg", uncompressedSize: 1,
                             compressedSize: 1, method: 0, crc32: 0, localHeaderOffset: 0)
        let wanted = Fixture.reference(uid: UUID(), attachmentFileName: "wanted.jpg")

        let landing = ArchiveRestoreWriter.materialize(
            archive { $0.exercises = [Fixture.exercise(uid: UUID(), references: [wanted])] },
            referenceImages: ["wanted.jpg": entry, "stray.jpg": entry],
            existing: RestoreExistingKeys())

        XCTAssertEqual(Set(landing.referenceImages.keys), ["wanted.jpg"])
    }

    /// D7's rewrite is the *receive* door's problem, because that one mints uids. A restore preserves
    /// them, so the leaf name is unchanged — and a name that collided would mean a uid that collided,
    /// which the owner's skip has already handled.
    func testAnAttachmentKeepsItsLeafNameBecauseItsUIDIsPreserved() {
        let uid = UUID()
        let record = Fixture.reference(uid: uid, attachmentFileName: "\(uid.uuidString).jpg")
        let landing = landed(archive { $0.exercises = [Fixture.exercise(uid: UUID(), references: [record])] })
        let link = try? XCTUnwrap(landing.exercises.first?.references.first)

        XCTAssertEqual(link?.uid, uid)
        XCTAssertEqual(link?.attachmentFileName, "\(uid.uuidString).jpg")
        XCTAssertEqual(link?.kindRaw, "image")
    }

    // MARK: - Songs

    /// Song audio is never in an archive, and this is the assertion that pins the consequence: the
    /// name comes back, the file does not, and the song needs a relink (ADR 0152).
    func testASongComesBackWithoutItsAudio() {
        let landing = landed(archive {
            $0.songs = [Fixture.song(sourceID: "song-1", loops: [Fixture.loop(uid: UUID())])]
        })
        let song = try? XCTUnwrap(landing.songs.first)

        XCTAssertEqual(song?.audioFileName, "song-1.m4a", "the name is restored")
        XCTAssertNil(song?.bookmark, "and there is no bookmark to restore — it was never exported")
        XCTAssertEqual(song?.loops.count, 1, "the practice built on it survives")
        XCTAssertEqual(song?.markers.count, 1)
        XCTAssertEqual(song?.preciseBPM, 92.4, "and so does the grid")
    }

    // MARK: - Goals and the practice log

    func testAGoalWhoseTargetSongIsMissingStillLands() {
        let landing = landed(archive {
            $0.goals = [GoalRecord(uid: UUID(), title: "Play it clean", weight: 2, skillIDs: ["timing"],
                                   targetSongID: "not-here", isMet: false, dateAdded: Fixture.date)]
        })
        XCTAssertEqual(landing.goals.first?.title, "Play it clean")
        XCTAssertNil(landing.goals.first?.targetSong)
    }

    func testThePracticeLogRestoresItsLooseIDsUntouched() {
        let unitUID = UUID()
        let runUID = UUID()
        let landing = landed(archive {
            $0.practiceRuns = [SessionRecord(id: runUID, startedAt: Fixture.date, durationSeconds: 600,
                                             kind: .exercise, unitUID: unitUID, tempoBPM: 96)]
        })
        let run = try? XCTUnwrap(landing.runs.first)

        XCTAssertEqual(run?.uid, runUID)
        XCTAssertEqual(run?.unitUID, unitUID, "a loose id: a run outlives the unit it logged")
        XCTAssertEqual(run?.tempoBPM, 96)
    }

    // MARK: - Saved chords

    func testASavedChordWithNoVoicingIsSkippedRatherThanLandedEmpty() {
        let landing = landed(archive {
            $0.savedChords = [SavedChordRecord(uid: UUID(), name: "Amaj7", createdAt: Fixture.date,
                                               voicing: nil)]
        })
        XCTAssertTrue(landing.savedChords.isEmpty, "a chord is its voicing; a row without one has no reading")
    }
}
