import XCTest
@testable import Pocket

/// What a restore says it will do before it does any of it (ADR 0188 D1, D9).
///
/// Pure: `RestorePlan.make` takes the keys already read off the store rather than a context to read
/// them from, which is what lets the skip rule be asserted over plain values instead of against an
/// in-memory container that does not behave like the real one.
final class ArchiveRestorePlanTests: XCTestCase {

    private let songID = "song-1"
    private let exerciseUID = UUID()
    private let routineUID = UUID()
    private let takeUID = UUID()

    private func archive() -> PracticeArchive {
        var archive = PracticeArchive(exportedAt: Date(timeIntervalSince1970: 1000),
                                      appVersion: "1.2 (5)", includesTakeAudio: true)
        archive.songs = [ArchiveFixture.song(sourceID: songID)]
        archive.exercises = [ArchiveFixture.exercise(uid: exerciseUID)]
        archive.routines = [ArchiveFixture.routine(uid: routineUID)]
        archive.takes = [ArchiveFixture.take(uid: takeUID, fileName: "take.m4a")]
        return archive
    }

    // MARK: - The skip rule

    func testEverythingLandsIntoAnEmptyLibrary() {
        let plan = RestorePlan.make(for: archive(), existing: RestoreExistingKeys(), takeAudio: ["take.m4a"])

        XCTAssertEqual(plan.landingCount, 4)
        XCTAssertEqual(plan.alreadyPresentCount, 0)
        XCTAssertFalse(plan.isEmpty)
    }

    /// D1's restore column: a uid the library already has is **skipped**, not merged and not replaced.
    func testARowTheLibraryAlreadyHasIsCountedAsPresentRatherThanLanding() {
        var existing = RestoreExistingKeys()
        existing.exerciseUIDs = [exerciseUID]
        existing.songSourceIDs = [songID]

        let plan = RestorePlan.make(for: archive(), existing: existing, takeAudio: ["take.m4a"])
        let byKind = Dictionary(plan.lines.map { ($0.kind, $0) }, uniquingKeysWith: { first, _ in first })

        XCTAssertEqual(byKind[.exercises]?.landing, 0)
        XCTAssertEqual(byKind[.exercises]?.alreadyPresent, 1)
        XCTAssertEqual(byKind[.songs]?.alreadyPresent, 1)
        XCTAssertEqual(byKind[.routines]?.landing, 1, "a kind the library lacks still lands")
    }

    /// The property that makes a restore trustworthy (D6): running it a second time does nothing.
    func testRestoringTwiceIsIdempotent() {
        var existing = RestoreExistingKeys()
        existing.songSourceIDs = [songID]
        existing.exerciseUIDs = [exerciseUID]
        existing.routineUIDs = [routineUID]
        existing.takeUIDs = [takeUID]

        let plan = RestorePlan.make(for: archive(), existing: existing, takeAudio: ["take.m4a"])
        XCTAssertTrue(plan.isEmpty, "a second run of the same archive has nothing left to add")
        XCTAssertEqual(plan.landingCount, 0)
    }

    // MARK: - Counting

    /// A kind the archive holds none of is left out rather than shown as zero — a player who keeps no
    /// journal should not be told they have no journal.
    func testKindsTheArchiveHasNoneOfAreNotListed() {
        let plan = RestorePlan.make(for: archive(), existing: RestoreExistingKeys(), takeAudio: [])
        XCTAssertFalse(plan.lines.contains { $0.kind == .journal })
        XCTAssertFalse(plan.lines.contains { $0.kind == .goals })
    }

    /// This door reads a file that may have been hand-edited. Counting a repeated uid twice would
    /// promise a number the writer, which skips it, then does not produce.
    func testARepeatedUIDInTheFileIsCountedOnce() {
        var archive = self.archive()
        archive.exercises.append(ArchiveFixture.exercise(uid: exerciseUID))

        let plan = RestorePlan.make(for: archive, existing: RestoreExistingKeys(), takeAudio: [])
        let exercises = plan.lines.first { $0.kind == .exercises }
        XCTAssertEqual(exercises?.landing, 1)
        XCTAssertEqual(exercises?.total, 1)
    }

    // MARK: - What the archive cannot bring back

    func testTakeAudioIsCountedPresentOrMissing() {
        var archive = self.archive()
        archive.takes.append(ArchiveFixture.take(uid: UUID(), fileName: "gone.m4a"))

        let plan = RestorePlan.make(for: archive, existing: RestoreExistingKeys(), takeAudio: ["take.m4a"])
        XCTAssertEqual(plan.takeAudioLanding, 1)
        XCTAssertEqual(plan.takeAudioMissing, 1, "a take row lands without its audio, and is counted")
    }

    /// Audio for a take the library already has is not re-written, so it is not counted either.
    func testAudioIsNotCountedForATakeThatIsBeingSkipped() {
        var existing = RestoreExistingKeys()
        existing.takeUIDs = [takeUID]

        let plan = RestorePlan.make(for: archive(), existing: existing, takeAudio: ["take.m4a"])
        XCTAssertEqual(plan.takeAudioLanding, 0)
        XCTAssertEqual(plan.takeAudioMissing, 0)
    }

    /// Song audio is never in an archive, so **every** landing song needs a relink. The count exists so
    /// the sheet can say that before the restore rather than leaving it to be discovered on play.
    func testEverySongThatLandsNeedsARelink() {
        let plan = RestorePlan.make(for: archive(), existing: RestoreExistingKeys(), takeAudio: [])
        XCTAssertEqual(plan.songsNeedingRelink, 1)
    }

    func testAProfileLandsOnlyIntoALibraryThatHasNone() {
        var archive = self.archive()
        archive.profile = ProfileRecord(uid: UUID(), artistName: "Jack", createdAt: Date(),
                                        experienceRaw: nil, genresRaw: [], dreamRaw: nil,
                                        minutesPerDayRaw: nil, preferredInstrumentRaw: nil)

        XCTAssertTrue(RestorePlan.make(for: archive, existing: RestoreExistingKeys(), takeAudio: []).landsProfile)

        var existing = RestoreExistingKeys()
        existing.hasProfile = true
        XCTAssertFalse(RestorePlan.make(for: archive, existing: existing, takeAudio: []).landsProfile)
    }

    /// An archive with nothing in it is not an error, and the sheet has to be able to say so.
    func testAnEmptyArchivePlansNothing() {
        let empty = PracticeArchive(exportedAt: Date(), appVersion: "1.2 (5)", includesTakeAudio: false)
        let plan = RestorePlan.make(for: empty, existing: RestoreExistingKeys(), takeAudio: [])
        XCTAssertTrue(plan.isEmpty)
        XCTAssertTrue(plan.lines.isEmpty)
    }
}
