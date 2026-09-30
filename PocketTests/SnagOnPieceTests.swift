import XCTest
@testable import Pocket

/// Snags on a piece (ADR 0234 D7): where one falls, what the Journal says about its line, where that line
/// leads, and that both new fields survive a backup. Models are built **uninserted** (the XCTest-host
/// insert trap, `docs/swiftdata-gotchas.md`).
final class SnagOnPieceTests: XCTestCase {

    // MARK: - Where a snag falls

    func testASnagFallsOnTheNearestTapWithinReach() {
        let taps: [TimeInterval] = [10, 10.4, 10.8, 13]
        XCTAssertEqual(SnagOnPiece.note(at: 10.4, taps: taps), 1, "one made on a note sits on it")
        XCTAssertEqual(SnagOnPiece.note(at: 10.55, taps: taps), 1, "a reaction lands after the note it caught")
        XCTAssertEqual(SnagOnPiece.note(at: 10.6, taps: taps), 1, "halfway goes to the earlier")
        XCTAssertEqual(SnagOnPiece.note(at: 12.2, taps: taps), 3)
        XCTAssertNil(SnagOnPiece.note(at: 11.9, taps: taps), "more than a second from any tap")
        XCTAssertNil(SnagOnPiece.note(at: 10, taps: []))
    }

    private func loopWithPiece() -> Loop {
        let song = Song(title: "Slow Bend", duration: 100, ref: SongRef(id: "s1", source: .localFile, bookmark: nil))
        let loop = Loop(name: "Intro lick", start: 0.1, end: 0.2, speed: 1, repeats: 1)
        loop.song = song
        song.loops = [loop]
        loop.transcription = PieceTranscription(taps: [.init(seconds: 11), .init(seconds: 12), .init(seconds: 13)])
        return loop
    }

    func testTheLoopPlacesTheSongsSnagsInsideItsSpanInOrder() throws {
        let loop = loopWithPiece()
        let song = try XCTUnwrap(loop.song)
        let late = Snag(seconds: 13.3, loopUID: nil)
        let early = Snag(seconds: 11, loopUID: loop.uid, markedWhileNaming: true)
        let outside = Snag(seconds: 40)
        let adrift = Snag(seconds: 19.5)
        song.snags = [late, outside, early, adrift]
        let placed = loop.snagsOnPiece
        XCTAssertEqual(placed.map(\.snag.uid), [early.uid, late.uid, adrift.uid],
                       "by position in the span, whichever loop was armed")
        XCTAssertEqual(placed.map(\.note), [0, 2, nil], "too far from any tap is on no note")
        XCTAssertEqual(loop.pieceNote(forSnag: late.uid), 2)
        XCTAssertNil(loop.pieceNote(forSnag: outside.uid))
    }

    // MARK: - The line, in the Journal

    private func line(on loop: Loop, snag: Snag?, kind: EntryKind = .ear) -> JournalEntry {
        let entry = JournalEntry.forLoop(text: "Hammer-on or two picks?", kind: kind, masteryAtEntry: nil,
                                         commandTempoAtEntry: nil)
        entry.loop = loop
        entry.snagUID = snag?.uid
        return entry
    }

    func testASnagsLineNamesItsNoteAndOpensNamingThere() throws {
        let loop = loopWithPiece()
        let snag = Snag(seconds: 12, loopUID: loop.uid, markedWhileNaming: true)
        try XCTUnwrap(loop.song).snags = [snag]
        let item = JournalTimeline.Item.note(line(on: loop, snag: snag))
        XCTAssertEqual(JournalTimeline.ownerLabel(for: item), "Slow Bend · Intro lick · note 2")
        guard case .naming(let routed, let note)? = JournalOwnerRoute.route(for: item) else {
            return XCTFail("a snag's line should open Name the notes on its note")
        }
        XCTAssertEqual(routed.uid, loop.uid)
        XCTAssertEqual(note, 1)
    }

    func testALineWhoseSnagIsGoneIsAnOrdinaryNote() throws {
        let loop = loopWithPiece()
        let gone = Snag(seconds: 12)
        let item = JournalTimeline.Item.note(line(on: loop, snag: gone))
        XCTAssertEqual(JournalTimeline.ownerLabel(for: item), "Slow Bend · Intro lick")
        guard case .loop(_, .ear)? = JournalOwnerRoute.route(for: item) else {
            return XCTFail("with its snag deleted, it opens the loop as any ear note does")
        }
    }

    func testASnagsLineNeverMarksTheLoopSolved() throws {
        let loop = loopWithPiece()
        let snag = Snag(seconds: 12, loopUID: loop.uid, markedWhileNaming: true)
        try XCTUnwrap(loop.song).snags = [snag]
        loop.journal = [line(on: loop, snag: snag, kind: .transcribed)]
        XCTAssertEqual(loop.line(forSnag: snag.uid)?.text, "Hammer-on or two picks?")
        XCTAssertEqual(SongMapInput(song: try XCTUnwrap(loop.song)).loops.first?.handTagged, false,
                       "a stuck note is not a declaration the loop is solved, even tagged 🧩")
        loop.journal.append(line(on: loop, snag: nil, kind: .transcribed))
        XCTAssertEqual(SongMapInput(song: try XCTUnwrap(loop.song)).loops.first?.handTagged, true)
    }

    // MARK: - The backup

    private func archive(snag: SnagRecord, entry: JournalEntryRecord) -> PracticeArchive {
        var archive = PracticeArchive(exportedAt: ArchiveFixture.date, appVersion: "1.3", includesTakeAudio: false)
        var song = ArchiveFixture.song(sourceID: "song-1", loops: [])
        song.snags = [snag]
        archive.songs = [song]
        archive.journal = [entry]
        return archive
    }

    func testBothFieldsSurviveAnEncodeAndDecodeAndAnOlderFileStillReads() throws {
        let snagUID = UUID()
        var entry = ArchiveFixture.journalEntry(uid: UUID())
        entry.snagUID = snagUID
        let written = archive(snag: SnagRecord(uid: snagUID, markedAt: ArchiveFixture.date, seconds: 12,
                                               markedWhileNaming: true), entry: entry)
        let read = try ArchiveBuilder.decode(ArchiveBuilder.encode(written))
        XCTAssertEqual(read.songs.first?.snags.first?.markedWhileNaming, true)
        XCTAssertEqual(read.journal.first?.snagUID, snagUID)

        let older = try ArchiveBuilder.encode(archive(snag: SnagRecord(uid: UUID(), markedAt: ArchiveFixture.date,
                                                                       seconds: 12),
                                                      entry: ArchiveFixture.journalEntry(uid: UUID())))
        let text = try XCTUnwrap(String(bytes: older, encoding: .utf8))
        XCTAssertFalse(text.contains("markedWhileNaming") || text.contains("snagUID"), "a file from before")
        let decoded = try ArchiveBuilder.decode(older)
        XCTAssertNil(decoded.songs.first?.snags.first?.markedWhileNaming)
        XCTAssertNil(decoded.journal.first?.snagUID)
    }

    @MainActor
    func testRestoreLandsBothFields() throws {
        let snagUID = UUID()
        var entry = ArchiveFixture.journalEntry(uid: UUID())
        entry.snagUID = snagUID
        let landing = ArchiveRestoreWriter.materialize(
            archive(snag: SnagRecord(uid: snagUID, markedAt: ArchiveFixture.date, seconds: 12,
                                     markedWhileNaming: true), entry: entry),
            existing: RestoreExistingKeys())
        XCTAssertEqual(landing.songs.first?.snags.first?.markedWhileNaming, true)
        XCTAssertEqual(landing.journal.first?.snagUID, snagUID)
    }
}
