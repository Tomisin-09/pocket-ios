import XCTest
@testable import Pocket

/// **The Pieces scope, grouped by song** (ADR 0232 D20): one group per song, the songs by when their newest
/// piece changed, the pieces in song order. Models are built **uninserted**, as the rest of the Journal's
/// tests build them (`docs/swiftdata-gotchas.md`).
final class JournalSongPiecesTests: XCTestCase {

    private let day: TimeInterval = 86_400
    private let now = Date(timeIntervalSinceReferenceDate: 800_000_000)

    private func song(_ title: String) -> Song {
        Song(title: title, duration: 200, ref: SongRef(id: title, source: .localFile, bookmark: nil))
    }

    /// A feed item for a piece on a loop of `song` from `start` to `end`, changed `daysAgo` days ago.
    private func piece(on song: Song?, _ name: String, start: Double, end: Double? = nil,
                       daysAgo: Double) -> JournalTimeline.Item {
        let loop = Loop(name: name, start: start, end: end ?? start + 0.1, speed: 1, repeats: 4)
        loop.song = song
        let transcription = PieceTranscription(taps: [.init(seconds: 20, label: .pitchClass(1))])
        return .piece(JournalPiece(loop: loop, piece: transcription, date: now - daysAgo * day))
    }

    private func titles(_ groups: [JournalSongPieces]) -> [String?] { groups.map { $0.song?.title } }
    private func names(_ group: JournalSongPieces) -> [String] { group.pieces.map(\.loop.name) }

    func testSongsRunByTheirNewestPieceAndOldestTurnsThatRound() {
        let bend = song("Slow Bend"), moon = song("Red Moon")
        // Slow Bend's newest piece (1 day ago) is newer than Red Moon's (2 days ago), though its oldest
        // (3 days ago) is older than anything on Red Moon.
        let items = [piece(on: bend, "Intro", start: 0.1, daysAgo: 3),
                     piece(on: moon, "Riff", start: 0.2, daysAgo: 2),
                     piece(on: bend, "Verse", start: 0.3, daysAgo: 1)]
        XCTAssertEqual(titles(JournalSongPieces.group(items, order: .newest)), ["Slow Bend", "Red Moon"])
        XCTAssertEqual(titles(JournalSongPieces.group(items, order: .oldest)), ["Red Moon", "Slow Bend"])
        let latest = JournalSongPieces.group(items, order: .newest).map(\.latest)
        XCTAssertEqual(latest, [now - day, now - 2 * day], "a song is dated by its newest piece")
    }

    func testWithinASongPiecesRunInSongOrderWhicheverWayTheFeedIsSorted() {
        let bend = song("Slow Bend")
        // Changed in the opposite order to where they play.
        let items = [piece(on: bend, "Outro", start: 0.8, daysAgo: 0),
                     piece(on: bend, "Intro", start: 0.1, daysAgo: 4),
                     piece(on: bend, "Verse", start: 0.3, daysAgo: 2)]
        for order in JournalTimeline.SortOrder.allCases {
            let group = JournalSongPieces.group(items, order: order)
            XCTAssertEqual(group.count, 1, "one song, one group")
            XCTAssertEqual(names(group[0]), ["Intro", "Verse", "Outro"], "\(order)")
            XCTAssertEqual(group[0].lead.name, "Intro", "the song is stood for by where it starts")
            XCTAssertEqual(group[0].id, group[0].lead.uid)
        }
    }

    func testTwoPiecesStartingTogetherTheShorterGoesFirst() {
        let bend = song("Slow Bend")
        let items = [piece(on: bend, "Verse and chorus", start: 0.3, end: 0.6, daysAgo: 1),
                     piece(on: bend, "Verse", start: 0.3, end: 0.45, daysAgo: 2)]
        XCTAssertEqual(names(JournalSongPieces.group(items, order: .newest)[0]), ["Verse", "Verse and chorus"])
    }

    func testSongsChangedAtTheSameMomentRunByTitle() {
        let items = [piece(on: song("Slow Bend"), "Intro", start: 0.1, daysAgo: 1),
                     piece(on: song("Red Moon"), "Riff", start: 0.1, daysAgo: 1)]
        XCTAssertEqual(titles(JournalSongPieces.group(items, order: .newest)), ["Red Moon", "Slow Bend"])
    }

    func testOnlyPiecesAreGroupedAndOnesWithNoSongComeLastEitherWay() {
        let note = JournalEntry.forLoop(text: "buzzing", kind: .struggle, masteryAtEntry: nil,
                                        commandTempoAtEntry: nil, createdAt: now)
        let items = [.note(note),
                     piece(on: nil, "Lost lick", start: 0.1, daysAgo: 0),
                     piece(on: song("Slow Bend"), "Intro", start: 0.1, daysAgo: 5),
                     piece(on: nil, "Other lick", start: 0.05, daysAgo: 3)]
        for order in JournalTimeline.SortOrder.allCases {
            let groups = JournalSongPieces.group(items, order: order)
            XCTAssertEqual(titles(groups), ["Slow Bend", nil], "\(order): newer, but it can't be mapped")
            XCTAssertEqual(names(groups[1]), ["Other lick", "Lost lick"], "\(order): one group, in order")
        }
        XCTAssertTrue(JournalSongPieces.group([.note(note)], order: .newest).isEmpty, "a note is no piece")
    }
}
