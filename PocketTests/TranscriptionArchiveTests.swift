import XCTest
@testable import Pocket

/// A loop's piece (ADR 0225) **in a backup**: written as readable structure, absent from a file made
/// before it, and landed back on the loop by a restore.
final class TranscriptionArchiveTests: XCTestCase {

    private let piece = PieceTranscription(taps: [.init(seconds: 30.4, label: .fretted(string: 1, fret: 5)),
                                                  .init(seconds: 30.9, label: .pitchClass(2)),
                                                  .init(seconds: 31.3)],
                                           openMidi: [64, 59, 55, 50, 45, 40],
                                           tuningLabel: "Guitar · Standard")

    private func archive(_ loops: [LoopRecord]) -> PracticeArchive {
        var archive = PracticeArchive(exportedAt: ArchiveFixture.date, appVersion: "1.3",
                                      includesTakeAudio: false)
        archive.songs = [ArchiveFixture.song(sourceID: "song-1", loops: loops)]
        return archive
    }

    private func transcribedRecord() -> LoopRecord {
        var record = ArchiveFixture.loop(uid: UUID())
        record.transcription = piece
        return record
    }

    func testThePieceSurvivesAnEncodeAndDecode() throws {
        let written = archive([transcribedRecord()])
        let read = try ArchiveBuilder.decode(ArchiveBuilder.encode(written))
        XCTAssertEqual(read.songs.first?.loops.first?.transcription, piece)
    }

    func testTheFileReadsAsStructureNotABlob() throws {
        let json = try XCTUnwrap(String(data: ArchiveBuilder.encode(archive([transcribedRecord()])),
                                        encoding: .utf8))
        XCTAssertTrue(json.contains("\"kind\" : \"fret\"") || json.contains("\"kind\":\"fret\""), json)
    }

    func testAFileFromBeforeCountTheNotesStillDecodes() throws {
        // The fixture has no piece, so its encoding has no key at all: a pre-0225 file.
        let data = try ArchiveBuilder.encode(archive([ArchiveFixture.loop(uid: UUID())]))
        XCTAssertFalse(try XCTUnwrap(String(bytes: data, encoding: .utf8)).contains("transcription"))
        let loop = try XCTUnwrap(ArchiveBuilder.decode(data).songs.first?.loops.first)
        XCTAssertNil(loop.transcription)
        XCTAssertEqual(loop.name, ArchiveFixture.loop(uid: UUID()).name, "the missing key took nothing else")
    }

    @MainActor
    func testABuilderWritesTheLoopsPiece() {
        let loop = Loop(name: "Lick", start: 0.2, end: 0.3, speed: 1, repeats: 1)
        loop.transcription = piece
        XCTAssertEqual(ArchiveBuilder.loopRecord(loop).transcription, piece)
    }

    @MainActor
    func testRestoreLandsThePiece() throws {
        let landing = ArchiveRestoreWriter.materialize(archive([transcribedRecord()]),
                                                       existing: RestoreExistingKeys())
        let loop = try XCTUnwrap(landing.songs.first?.loops.first)
        XCTAssertEqual(loop.transcription, piece)
    }
}
