import XCTest
@testable import Pocket

/// What an archive **becomes** (ADR 0188 S3, D1/D6/D7).
///
/// Asserted on the **uninserted** graph `materialize` returns, which is the contract that makes any of
/// this testable: inserting a full object graph in this host traps (`docs/swiftdata-gotchas.md`), so a
/// writer that went straight to a `ModelContext` could only ever be checked by hand on a device. The
/// same split S2 made for `ReceivedRoutineBuilder.materialize`.
///
/// The through-line of the whole file is the difference from that door. A receive mints uids and drops
/// the sender's history (D5); a restore preserves both, because it is the same player's library coming
/// home. Where an assertion here looks like the opposite of one in `ReceivedRoutineHydrationTests`,
/// that is D1's trust asymmetry being obeyed rather than a contradiction.
@MainActor
final class ArchiveRestoreHydrationTests: XCTestCase {

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

    // MARK: - Identity: the asymmetry that defines this door

    /// D1's restore column, and the assertion that everything else in a restore depends on: the ids
    /// are the file's. Journal entries, takes and blocks all point at rows by uid, so a minted uid
    /// would restore a library in which nothing written about a loop still found it.
    func testUIDsArePreservedRatherThanMinted() {
        let exerciseUID = UUID()
        let routineUID = UUID()
        let loopUID = UUID()
        let landing = landed(archive {
            $0.exercises = [Fixture.exercise(uid: exerciseUID)]
            $0.routines = [Fixture.routine(uid: routineUID)]
            $0.songs = [Fixture.song(sourceID: "song-1", loops: [Fixture.loop(uid: loopUID)])]
        })

        XCTAssertEqual(landing.exercises.first?.uid, exerciseUID)
        XCTAssertEqual(landing.routines.first?.routine.uid, routineUID)
        XCTAssertEqual(landing.songs.first?.loops.first?.uid, loopUID)
    }

    /// D6: a row the library already has is left exactly as it is — not merged, not overwritten.
    func testARowTheLibraryAlreadyHasIsNotBuiltAtAll() {
        let uid = UUID()
        var existing = RestoreExistingKeys()
        existing.exerciseUIDs = [uid]

        let landing = landed(archive { $0.exercises = [Fixture.exercise(uid: uid)] }, existing: existing)
        XCTAssertTrue(landing.exercises.isEmpty)
        XCTAssertEqual(landing.rowCount, 0)
    }

    /// `RestorePlan` counts a repeated uid once, so the writer has to build it once. Otherwise the
    /// preview promises a number the write exceeds, and the library ends up with two rows sharing the
    /// key that journal entries, takes and blocks all join on.
    func testARepeatedUIDInTheFileBuildsOneRow() {
        let exerciseUID = UUID()
        let routineUID = UUID()
        let takeUID = UUID()
        let payload = archive {
            $0.exercises = [Fixture.exercise(uid: exerciseUID), Fixture.exercise(uid: exerciseUID)]
            $0.routines = [Fixture.routine(uid: routineUID), Fixture.routine(uid: routineUID)]
            $0.takes = [Fixture.take(uid: takeUID, fileName: "a.m4a"),
                        Fixture.take(uid: takeUID, fileName: "b.m4a")]
        }
        let landing = landed(payload)
        let plan = RestorePlan.make(for: payload, existing: RestoreExistingKeys(), takeAudio: [])

        XCTAssertEqual(landing.exercises.count, 1)
        XCTAssertEqual(landing.routines.count, 1)
        XCTAssertEqual(landing.takes.count, 1)
        XCTAssertEqual(landing.rowCount, plan.landingCount,
                       "what the writer builds is what the preview promised")
    }

    // MARK: - The history a receive drops and a restore keeps

    /// The mirror image of `ReceivedRoutineHydrationTests`' D5 assertions. A teacher's mastery must not
    /// arrive wearing the receiver's name (ADR 0070); the player's own must come back, or a backup
    /// quietly resets a year of practice.
    func testADrillKeepsTheHistoryAShareWouldHaveDropped() {
        let landing = landed(archive { $0.exercises = [Fixture.exercise(uid: UUID())] })
        let drill = try? XCTUnwrap(landing.exercises.first)

        XCTAssertEqual(drill?.mastery, 4)
        XCTAssertEqual(drill?.masteryTempo, 108)
        XCTAssertEqual(drill?.commandTempo, 104)
        XCTAssertEqual(drill?.commandNotesPerBeat, 2)
        XCTAssertEqual(drill?.presetSlug, "spider-walk")
        XCTAssertEqual(drill?.isFavorite, true)
        XCTAssertEqual(drill?.lastPracticed, Fixture.date)
        XCTAssertEqual(drill?.dateAdded, Fixture.date)
    }

    func testALoopKeepsItsMasteryAndItsAutomatorSettings() {
        let landing = landed(archive {
            $0.songs = [Fixture.song(sourceID: "song-1", loops: [Fixture.loop(uid: UUID())])]
        })
        let loop = try? XCTUnwrap(landing.songs.first?.loops.first)

        XCTAssertEqual(loop?.mastery, 3)
        XCTAssertEqual(loop?.commandTempo, 88.5)
        XCTAssertEqual(loop?.focus, 2)
        XCTAssertEqual(loop?.automatorEnabled, true)
        XCTAssertEqual(loop?.automatorStepCount, 5)
        XCTAssertEqual(loop?.customColorHex, "FF8800")
    }

    // MARK: - Raw enum columns

    /// The trap S2 wrote into `ReceivedRoutineBuilder`, and it matters more here than there: this is
    /// the player's own library coming back, so a column silently normalised on the way in is data
    /// loss in the one operation whose entire purpose is not losing any.
    func testUnrecognisedEnumColumnsSurviveVerbatim() {
        var record = Fixture.exercise(uid: UUID())
        record.templateRaw = "orchestral-conducting"
        record.instrumentRaw = "theremin"
        record.subdivisionRaw = "septuplet"
        record.rampIntervalUnitRaw = "fortnights"

        let drill = try? XCTUnwrap(landed(archive { $0.exercises = [record] }).exercises.first)
        XCTAssertEqual(drill?.templateRaw, "orchestral-conducting")
        XCTAssertEqual(drill?.instrumentRaw, "theremin")
        XCTAssertEqual(drill?.subdivisionRaw, "septuplet")
        XCTAssertEqual(drill?.rampIntervalUnitRaw, "fortnights")
    }

    /// `Song.init` writes `ref.source.rawValue`, and `SongRef.Source` resolves an unknown value to
    /// `.localFile` — so the source has to be assigned raw, after the initialiser, like every other
    /// enum column. Easy to miss, because `Song` is the one model whose raw column is behind a struct.
    func testAnUnrecognisedSongSourceIsNotRewrittenByTheInitialiser() {
        var record = Fixture.song(sourceID: "song-1")
        record.sourceRaw = "someFutureSource"

        XCTAssertEqual(landed(archive { $0.songs = [record] }).songs.first?.sourceRaw, "someFutureSource")
    }

    func testAnUnrecognisedBlockKindSurvivesRatherThanFoldingToRest() {
        let landing = landed(archive {
            $0.routines = [Fixture.routine(uid: UUID(),
                                           items: [Fixture.block(order: 0, kindRaw: "improviseAlong")])]
        })
        XCTAssertEqual(landing.routines.first?.items.first?.kindRaw, "improviseAlong")
    }

    // MARK: - Pins (ADR 0190)

    func testAPinComesBackOnBothKindsOfRow() {
        let entryUID = UUID()
        let takeUID = UUID()
        let landing = landed(archive {
            var entry = Fixture.journalEntry(uid: entryUID)
            entry.isPinned = true
            $0.journal = [entry]
            var take = Fixture.take(uid: takeUID, fileName: "take-1.m4a")
            take.isPinned = true
            $0.takes = [take]
        })

        XCTAssertEqual(landing.journal.first?.isPinned, true)
        XCTAssertEqual(landing.takes.first?.0.isPinned, true)
    }

    /// An archive written before pins existed carries `nil`, and `nil` means **unpinned**, not
    /// unknown — the model column is a non-optional `Bool`. A restore that left it unset would still
    /// land `false` by declaration default; asserting it here is what stops a later refactor from
    /// turning the absent field into a pinned row.
    func testAnArchiveWrittenBeforePinsRestoresEverythingUnpinned() {
        let landing = landed(archive {
            var entry = Fixture.journalEntry(uid: UUID())
            entry.isPinned = nil
            $0.journal = [entry]
            var take = Fixture.take(uid: UUID(), fileName: "take-1.m4a")
            take.isPinned = nil
            $0.takes = [take]
        })

        XCTAssertEqual(landing.journal.first?.isPinned, false)
        XCTAssertEqual(landing.takes.first?.0.isPinned, false)
    }
}
