import SwiftData
import XCTest
@testable import Pocket

/// A loop's piece and its earlier versions (ADR 0233): saving again keeps the one before, using an earlier
/// one keeps the one in use, only an earlier one can be deleted, and all of it survives a backup.
@MainActor
final class PieceVersionsTests: XCTestCase {

    /// A one-tap piece, told apart by where its tap is.
    private func piece(_ seconds: TimeInterval) -> PieceTranscription {
        PieceTranscription(taps: [.init(seconds: seconds, label: .pitchClass(9))])
    }

    // MARK: - The rules (D3, D4)

    func testSavingOverAPieceKeepsItFirstAmongTheEarlierOnes() {
        var versions = PieceVersions(inUse: piece(1), kept: [piece(2)])
        versions.save(piece(3))
        XCTAssertEqual(versions, PieceVersions(inUse: piece(3), kept: [piece(1), piece(2)]))
    }

    func testTheFirstSaveKeepsNothing() {
        var versions = PieceVersions(inUse: nil, kept: [])
        versions.save(piece(1))
        XCTAssertEqual(versions, PieceVersions(inUse: piece(1), kept: []))
    }

    func testAnEmptyPassIsNeverSaved() {
        var versions = PieceVersions(inUse: piece(1), kept: [])
        versions.save(PieceTranscription(taps: []))
        XCTAssertEqual(versions, PieceVersions(inUse: piece(1), kept: []), "and the one in use isn't kept away")
    }

    func testUsingAnEarlierVersionKeepsTheOneInUseAndGoingBackIsTheSameAction() {
        var versions = PieceVersions(inUse: piece(1), kept: [piece(2), piece(3)])
        versions.use(1)
        XCTAssertEqual(versions, PieceVersions(inUse: piece(3), kept: [piece(1), piece(2)]))
        versions.use(0)
        XCTAssertEqual(versions.inUse, piece(1))
        XCTAssertEqual(versions.kept, [piece(3), piece(2)], "nothing is lost by switching")
    }

    func testDeletingRemovesThatEarlierVersionOnly() {
        var versions = PieceVersions(inUse: piece(1), kept: [piece(2), piece(3)])
        versions.delete(0)
        XCTAssertEqual(versions, PieceVersions(inUse: piece(1), kept: [piece(3)]))
    }

    func testAPlaceThatIsntThereChangesNothing() {
        var versions = PieceVersions(inUse: piece(1), kept: [piece(2)])
        versions.use(1)
        versions.delete(-1)
        versions.delete(1)
        XCTAssertEqual(versions, PieceVersions(inUse: piece(1), kept: [piece(2)]))
    }

    // MARK: - On the loop (D2)

    private func makeLoop() -> Loop {
        Loop(name: "Lick", start: 0.1, end: 0.2, speed: 1, repeats: 1)
    }

    func testTheLoopKeepsItsVersionsBesideThePieceInUse() {
        let loop = makeLoop()
        loop.pieceVersions.save(piece(1))
        XCTAssertNil(loop.keptTranscriptionsData, "none kept, none stored")
        loop.pieceVersions.save(piece(2))
        XCTAssertEqual(loop.transcription, piece(2), "the piece in use is where it always was")
        XCTAssertEqual(loop.keptTranscriptions, [piece(1)])
        loop.pieceVersions.delete(0)
        XCTAssertNil(loop.keptTranscriptionsData, "the last one deleted leaves nothing stored")
    }

    func testVersionsThatCantBeReadAreNoneAndLeaveThePieceInUseAlone() {
        let loop = makeLoop()
        loop.transcription = piece(1)
        loop.keptTranscriptionsData = Data("not a piece".utf8)
        XCTAssertEqual(loop.keptTranscriptions, [])
        XCTAssertEqual(loop.transcription, piece(1))
    }

    func testSaveInCountTheNotesKeepsThePieceItTakesOverFrom() throws {
        let loop = makeLoop()
        loop.song = Song(title: "Slow Bend", duration: 100, ref: SongRef(id: "s1", source: .localFile, bookmark: nil))
        loop.transcription = piece(10.2)
        let model = CountTheNotesModel(loop: loop)
        model.loopStarted()
        for elapsed in [0.5, 1.0] {
            model.tap(clock: LoopClockReading(elapsed: elapsed, regionStart: 10, passLength: 10, rate: 1,
                                              outputLatency: 0))
        }
        let container = try ModelContainer(for: Song.self, Loop.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        model.save(context: ModelContext(container))
        XCTAssertEqual(loop.transcription?.taps.map(\.seconds), [10.5, 11], "the new pass is in use")
        XCTAssertEqual(loop.keptTranscriptions, [piece(10.2)], "and the one before is kept, with no prompt")
    }

    // MARK: - The backup (D6)

    private func archive(loops: [LoopRecord]) -> PracticeArchive {
        var archive = PracticeArchive(exportedAt: ArchiveFixture.date, appVersion: "1.3", includesTakeAudio: false)
        archive.songs = [ArchiveFixture.song(sourceID: "song-1", loops: loops)]
        return archive
    }

    func testTheBackupWritesVersionsOnlyForALoopThatHasThem() throws {
        let loop = makeLoop()
        loop.pieceVersions.save(piece(1))
        XCTAssertNil(ArchiveBuilder.loopRecord(loop).keptTranscriptions, "no key for a loop with none")
        loop.pieceVersions.save(piece(2))
        XCTAssertEqual(ArchiveBuilder.loopRecord(loop).keptTranscriptions, [piece(1)])
    }

    func testVersionsSurviveAnEncodeAndDecodeAndAnOlderFileStillReads() throws {
        var kept = ArchiveFixture.loop(uid: UUID())
        kept.transcription = piece(3)
        kept.keptTranscriptions = [piece(2), piece(1)]
        let read = try ArchiveBuilder.decode(ArchiveBuilder.encode(archive(loops: [kept])))
        XCTAssertEqual(read.songs.first?.loops.first?.keptTranscriptions, [piece(2), piece(1)], "newest first")

        let older = try ArchiveBuilder.encode(archive(loops: [ArchiveFixture.loop(uid: UUID())]))
        XCTAssertFalse(try XCTUnwrap(String(bytes: older, encoding: .utf8)).contains("keptTranscriptions"))
        let loop = try XCTUnwrap(ArchiveBuilder.decode(older).songs.first?.loops.first)
        XCTAssertNil(loop.keptTranscriptions)
        XCTAssertEqual(loop.name, "Turnaround", "the missing key took nothing else")
    }

    func testRestoreLandsTheVersions() throws {
        let uid = UUID()
        var kept = ArchiveFixture.loop(uid: uid)
        kept.transcription = piece(3)
        kept.keptTranscriptions = [piece(2)]
        let landing = ArchiveRestoreWriter.materialize(archive(loops: [kept, ArchiveFixture.loop(uid: UUID())]),
                                                       existing: RestoreExistingKeys())
        let loops = try XCTUnwrap(landing.songs.first?.loops)
        XCTAssertEqual(loops.first { $0.uid == uid }?.transcription, piece(3))
        XCTAssertEqual(loops.first { $0.uid == uid }?.keptTranscriptions, [piece(2)])
        XCTAssertEqual(loops.first { $0.uid != uid }?.keptTranscriptions, [], "an older loop has none")
    }
}
