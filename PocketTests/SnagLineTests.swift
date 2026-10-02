import XCTest
@testable import Pocket

/// A line on a snag from the waveform (ADR 0238): which loop's Journal a new one goes to, what kind it is,
/// which line a snag has, and that *Name the notes* and the *Snags* panel read the same one. Models are
/// built **uninserted** (the XCTest-host insert trap, `docs/swiftdata-gotchas.md`).
final class SnagLineTests: XCTestCase {

    private let riff = UUID()
    private let chorus = UUID()
    private let outro = UUID()

    private var spans: [SnagLine.Span] {
        [.init(uid: riff, start: 10, end: 20),
         .init(uid: chorus, start: 5, end: 40),
         .init(uid: outro, start: 60, end: 70)]
    }

    // MARK: - Where a new line goes

    func testANewLineGoesToTheLoopItWasMadeUnder() {
        XCTAssertEqual(SnagLine.home(madeUnder: chorus, at: 12, among: spans), chorus,
                       "the loop its row names, not the tightest one that holds it")
        XCTAssertEqual(SnagLine.home(madeUnder: outro, at: 12, among: spans), outro,
                       "even when that loop has since moved off it")
    }

    func testWithItsLoopGoneTheTightestLoopHoldingItTakesTheLine() {
        let gone = UUID()
        XCTAssertEqual(SnagLine.home(madeUnder: gone, at: 12, among: spans), riff)
        XCTAssertEqual(SnagLine.home(madeUnder: gone, at: 30, among: spans), chorus)
        XCTAssertEqual(SnagLine.home(madeUnder: nil, at: 20, among: spans), riff, "the span's ends are inside it")
    }

    func testOfTwoLoopsTheSameLengthTheEarlierTakesTheLine() {
        let later = UUID()
        let earlier = UUID()
        let even: [SnagLine.Span] = [.init(uid: later, start: 12, end: 22), .init(uid: earlier, start: 8, end: 18)]
        XCTAssertEqual(SnagLine.home(madeUnder: nil, at: 15, among: even), earlier)
    }

    func testNoLoopHoldingItMeansNowhereToWrite() {
        XCTAssertNil(SnagLine.home(madeUnder: UUID(), at: 50, among: spans))
        XCTAssertNil(SnagLine.home(madeUnder: nil, at: 12, among: []))
    }

    // MARK: - What kind it is

    func testAStumblesLineIsAStruggleAndAStuckNotesIsEar() {
        XCTAssertEqual(SnagLine.kind(markedWhileNaming: nil), .struggle, "made while playing")
        XCTAssertEqual(SnagLine.kind(markedWhileNaming: false), .struggle)
        XCTAssertEqual(SnagLine.kind(markedWhileNaming: true), .ear, "as Name the notes writes it")
        XCTAssertNotEqual(SnagLine.kind(markedWhileNaming: true), .transcribed, "the map reads 🧩 as solved")
        XCTAssertNotEqual(SnagLine.kind(markedWhileNaming: nil), .transcribed)
    }

    // MARK: - Which line a snag has

    private func entry(_ text: String, snag: UUID?, at seconds: TimeInterval) -> JournalEntry {
        let entry = JournalEntry.forLoop(text: text, kind: .struggle, masteryAtEntry: nil, commandTempoAtEntry: nil)
        entry.snagUID = snag
        entry.createdAt = Date(timeIntervalSince1970: seconds)
        return entry
    }

    func testASnagsLineIsTheLatestNoteTiedToIt() {
        let snag = UUID()
        let other = UUID()
        let lines = SnagLine.lines(in: [entry("newer", snag: snag, at: 200),
                                        entry("untied", snag: nil, at: 300),
                                        entry("older", snag: snag, at: 100),
                                        entry("another", snag: other, at: 50)])
        XCTAssertEqual(lines[snag]?.text, "newer")
        XCTAssertEqual(lines[other]?.text, "another")
        XCTAssertEqual(lines.count, 2, "a note tied to no snag is no snag's line")
    }

    /// The waveform writes a new line to the loop the snag was made under. *Name the notes* on another loop
    /// that holds the same snag has to show it too, or the two places split one snag's line in two.
    func testNameTheNotesReadsALineWrittenInAnotherLoopsJournal() {
        let song = Song(title: "Slow Bend", duration: 100, ref: SongRef(id: "s1", source: .localFile, bookmark: nil))
        let made = Loop(name: "Verse", start: 0.05, end: 0.4, speed: 1, repeats: 1)
        let named = Loop(name: "Intro lick", start: 0.1, end: 0.2, speed: 1, repeats: 1)
        made.song = song
        named.song = song
        song.loops = [made, named]
        let snag = Snag(seconds: 12, loopUID: made.uid)
        song.snags = [snag]
        let line = entry("The slide lands late", snag: snag.uid, at: 100)
        made.journal = [line]

        XCTAssertEqual(named.line(forSnag: snag.uid)?.text, "The slide lands late")
        XCTAssertEqual(made.line(forSnag: snag.uid)?.text, "The slide lands late")
        XCTAssertNil(named.line(forSnag: UUID()))
    }

    func testALoopWithNoSongStillReadsItsOwnJournal() {
        let loop = Loop(name: "Loose", start: 0.1, end: 0.2, speed: 1, repeats: 1)
        let snag = UUID()
        loop.journal = [entry("Mine", snag: snag, at: 10)]
        XCTAssertEqual(loop.line(forSnag: snag)?.text, "Mine")
    }
}
