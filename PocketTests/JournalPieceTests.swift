import XCTest
@testable import Pocket

/// **Pieces in the Journal** (ADR 0229): one row per loop's saved piece, drawn from the piece and dated by
/// when it last changed, in place of a 🧩 line per save. Models are built **uninserted**, as the rest of
/// the Journal's tests build them (`docs/swiftdata-gotchas.md`).
final class JournalPieceTests: XCTestCase {

    private let day: TimeInterval = 86_400
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func makeLoop(piece: PieceTranscription?, measured: Bool = true) -> Loop {
        let loop = Loop(name: "Intro licks", start: 0.1, end: 0.25, speed: 1, repeats: 4)
        if measured { loop.commandTempo = 0.9 }
        loop.song = Song(title: "Slow Bend", duration: 200, ref: SongRef(id: "s1", source: .localFile, bookmark: nil))
        loop.transcription = piece
        return loop
    }

    private func piece(changedAt: Date?) -> PieceTranscription {
        var piece = PieceTranscription(taps: [.init(seconds: 20, label: .pitchClass(1)), .init(seconds: 21)])
        piece.changedAt = changedAt
        return piece
    }

    /// The feed item for a measured loop's piece, changed now.
    private func shownItem() throws -> JournalTimeline.Item {
        .piece(try XCTUnwrap(JournalPiece.all(in: [makeLoop(piece: piece(changedAt: now))]).first))
    }

    private func transcribedLine(at date: Date) -> JournalEntry {
        JournalEntry.forLoop(text: "2 notes. C♯ ?", kind: .transcribed, masteryAtEntry: nil,
                             commandTempoAtEntry: nil, createdAt: date)
    }

    // MARK: - Which pieces show, and when

    func testAPieceIsDatedByWhenItLastChanged() throws {
        let loop = makeLoop(piece: piece(changedAt: now))
        let shown = try XCTUnwrap(JournalPiece.all(in: [loop, makeLoop(piece: nil)]).first)
        XCTAssertEqual(JournalPiece.all(in: [loop, makeLoop(piece: nil)]).count, 1, "a loop with no piece has no row")
        XCTAssertEqual(shown.date, now)
        XCTAssertEqual(shown.loop.uid, loop.uid)
    }

    func testAnUndatedPieceTakesItsNewestTranscribedLineAndWithoutOneIsLeftOut() throws {
        let loop = makeLoop(piece: piece(changedAt: nil))
        XCTAssertTrue(JournalPiece.all(in: [loop]).isEmpty, "no date to put it on")
        loop.journal = [transcribedLine(at: now - 3 * day), transcribedLine(at: now - day)]
        XCTAssertEqual(try XCTUnwrap(JournalPiece.all(in: [loop]).first).date, now - day, "the newest save")
    }

    // MARK: - On the feed

    func testPiecesJoinTheFeedAndHaveAScopeOfTheirOwn() {
        let note = JournalEntry.forLoop(text: "buzzing", kind: .struggle, masteryAtEntry: nil,
                                        commandTempoAtEntry: nil, createdAt: now - day)
        let items = JournalTimeline.merge(entries: [note], takes: [],
                                          pieces: JournalPiece.all(in: [makeLoop(piece: piece(changedAt: now))]))
        XCTAssertEqual(items.map(\.isPiece), [true, false], "newest first, the piece changed after the note")
        let pieces = JournalTimeline.filter(items, scope: .pieces)
        XCTAssertEqual(pieces.map(\.isPiece), [true], "just the piece")
        XCTAssertFalse(JournalTimeline.filter(items, scope: .notes).contains(where: \.isPiece))
        XCTAssertFalse(JournalTimeline.filter(items, scope: .takes).contains(where: \.isPiece))
        XCTAssertEqual(JournalTimeline.filter(items, scope: .all).count, 2)
    }

    func testAPieceFiltersAsALoopsAndAsTranscribedAndIsNeverPinned() throws {
        let item = try shownItem()
        XCTAssertEqual(JournalTimeline.OwnerFilter.bucket(for: item), .loop)
        XCTAssertTrue(JournalTimeline.TagSelection([.transcribed]).matches(item), "🧩 brings the pieces")
        XCTAssertFalse(JournalTimeline.TagSelection([.idea]).matches(item))
        XCTAssertFalse(item.isPinned)
        XCTAssertTrue(JournalTimeline.filter([item], pinnedOnly: true).isEmpty)
        XCTAssertEqual(JournalTimeline.ownerLabel(for: item), "Slow Bend · Intro licks")
        XCTAssertEqual(JournalTimeline.filter([item], query: "piece").count, 1)
        XCTAssertEqual(JournalTimeline.filter([item], query: "intro").count, 1)
    }

    func testAPieceOpensEarTrainingEvenOnAMeasuredLoop() throws {
        let item = try shownItem()
        guard case .loop(_, let mode)? = JournalOwnerRoute.route(for: item) else {
            return XCTFail("a piece opens its loop")
        }
        XCTAssertEqual(mode, .ear, "where it was made and where Name the notes opens")
    }

    // MARK: - Dating the pieces saved before

    func testTheBackfillDatesAnUndatedPieceByItsLineElseToday() throws {
        let lined = makeLoop(piece: piece(changedAt: nil))
        lined.journal = [transcribedLine(at: now - 2 * day)]
        XCTAssertTrue(PieceDateBackfill.apply(to: lined, now: now))
        XCTAssertEqual(lined.transcription?.changedAt, now - 2 * day)

        let bare = makeLoop(piece: piece(changedAt: nil))
        XCTAssertTrue(PieceDateBackfill.apply(to: bare, now: now))
        XCTAssertEqual(bare.transcription?.changedAt, now, "no line left: the first day it shows")

        XCTAssertFalse(PieceDateBackfill.apply(to: lined, now: now + day), "a dated piece is left alone")
        XCTAssertEqual(lined.transcription?.changedAt, now - 2 * day)
        XCTAssertFalse(PieceDateBackfill.apply(to: makeLoop(piece: nil), now: now))
    }

    // MARK: - The date on the piece

    func testTheDateRoundTripsAndAnOlderPieceDecodesWithoutOne() throws {
        let dated = piece(changedAt: now)
        XCTAssertEqual(PieceTranscription.decoded(from: dated.encoded())?.changedAt, now)
        let older = Data(#"{"version":1,"taps":[{"seconds":20}]}"#.utf8)
        let decoded = try XCTUnwrap(PieceTranscription.decoded(from: older))
        XCTAssertNil(decoded.changedAt)
        XCTAssertEqual(decoded.count, 1)
    }

    func testThePiecesLineIsTheSavedLine() {
        XCTAssertEqual(piece(changedAt: nil).summary(spelling: .sharps), "2 notes. C♯ ?")
    }
}
