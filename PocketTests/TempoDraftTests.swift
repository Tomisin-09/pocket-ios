import XCTest
@testable import Pocket

/// The tempo sheet's tempo before Done (ADR 0284): Half and Double on every source, the typed-tempo
/// rule that replaced the Manual field's, the words around the tempo, and what heads the sheet.
final class TempoDraftTests: XCTestCase {

    /// An estimate with no envelope, so Half and Double keep its 1 rather than finding another.
    private func estimate(_ bpm: Double, one: TimeInterval? = 0.4) -> TempoDraft {
        TempoDraft(reading: .init(estimate: .init(bpm: bpm, downbeatSeconds: one), onsets: [],
                                  framesPerSecond: 100))
    }

    // MARK: Half and Double

    /// An estimate is counted again, so it stays an estimate, exact, with its reading.
    func testHalfAnEstimateIsTheReadingCountedAgain() throws {
        let half = try XCTUnwrap(estimate(166.003).scaled(by: 0.5))
        XCTAssertEqual(half.bpm, 83.0015)
        XCTAssertEqual(half.source, .estimated)
        XCTAssertEqual(half.reading?.estimate.bpm, 83.0015)
    }

    /// A tapped tempo can be double time too, and half of the player's taps is still theirs.
    func testHalfATappedTempoKeepsItsSource() throws {
        let half = try XCTUnwrap(TempoDraft(bpm: 166, source: .tapped).scaled(by: 0.5))
        XCTAssertEqual(half, TempoDraft(bpm: 83, source: .tapped))
        XCTAssertNil(half.reading)
    }

    func testDoubleTheSongsOwnTempo() throws {
        let double = try XCTUnwrap(TempoDraft(bpm: 41.5, source: .song).scaled(by: 2))
        XCTAssertEqual(double, TempoDraft(bpm: 83, source: .song))
    }

    func testScalingPastTheTappableRangeIsRefused() {
        let fast = TempoDraft(bpm: 200, source: .typed)
        XCTAssertFalse(fast.allows(2))
        XCTAssertNil(fast.scaled(by: 2))
        XCTAssertTrue(fast.allows(0.5))

        XCTAssertNil(estimate(50).scaled(by: 0.5))
        XCTAssertFalse(estimate(50).allows(0.5))
    }

    // MARK: Type a tempo

    /// The field takes whole numbers. Typing the tempo shown keeps it exact (ADR 0282).
    func testTypingTheTempoShownKeepsItExact() {
        XCTAssertEqual(TempoDraft.typed("83", showing: 83.0015), 83.0015)
        XCTAssertEqual(TempoDraft.typed(" 84 ", showing: 83.9), 83.9)
    }

    func testATypedTempoIsTheNumberTyped() {
        XCTAssertEqual(TempoDraft.typed("92.5", showing: 84), 92.5)
        XCTAssertEqual(TempoDraft.typed("92", showing: nil), 92)
        XCTAssertEqual(TempoDraft.typed("84", showing: 83.0015), 84)
    }

    /// A decimal pad in a comma locale types `92,5`.
    func testACommaIsADecimalPoint() {
        XCTAssertEqual(TempoDraft.typed("92,5", showing: nil), 92.5)
    }

    func testATypedTempoIsClampedToTheTappableRange() {
        XCTAssertEqual(TempoDraft.typed("999", showing: 84), TempoMath.maxTapBPM)
        XCTAssertEqual(TempoDraft.typed("5", showing: nil), TempoMath.minTapBPM)
    }

    func testNothingUsableTypedSetsNothing() {
        XCTAssertNil(TempoDraft.typed("", showing: 84))
        XCTAssertNil(TempoDraft.typed("fast", showing: 84))
        XCTAssertNil(TempoDraft.typed("0", showing: nil))
        XCTAssertNil(TempoDraft.typed("-90", showing: nil))
    }

    // MARK: The words around the tempo

    func testEachSourceSaysWhereTheTempoCameFrom() {
        XCTAssertEqual(TempoDraft(bpm: 83, source: .song).sourceLine, "This song's tempo")
        XCTAssertEqual(estimate(83).sourceLine, "Estimated from the song")
        XCTAssertEqual(TempoDraft(bpm: 83, source: .tapped).sourceLine, "From your taps")
        XCTAssertEqual(TempoDraft(bpm: 83, source: .typed).sourceLine, "Typed in")
    }

    func testTheSummaryCountsTheBarAndPlacesTheOne() {
        XCTAssertEqual(TempoDraft.summary(beatsPerBar: 4, noteValue: 4, name: "4/4", downbeat: 2.2),
                       "4 beats a bar · the 1 at 0:02")
        XCTAssertEqual(TempoDraft.summary(beatsPerBar: 3, noteValue: 4, name: "3/4", downbeat: nil),
                       "3 beats a bar · no 1 yet")
    }

    /// *6 beats a bar* isn't how a 6/8 song is counted, so a meter in eighths reads as its name.
    func testAMeterInEighthsReadsAsItsName() {
        XCTAssertEqual(TempoDraft.summary(beatsPerBar: 6, noteValue: 8, name: "6/8", downbeat: 61),
                       "6/8 · the 1 at 1:01")
    }

    // MARK: What heads the sheet

    func testASongWithNoTempoOpensOnFindTheTempo() {
        let top = TempoSheetTop(draft: nil, isListening: false, hasBeatMap: false, songBPM: nil)
        XCTAssertEqual(top, .find)
        XCTAssertNil(top.shown)
        XCTAssertFalse(top.offersFindAgain)
    }

    func testASongWithATempoOpensOnIt() {
        let top = TempoSheetTop(draft: nil, isListening: false, hasBeatMap: false, songBPM: 83.0015)
        XCTAssertEqual(top.shown, TempoDraft(bpm: 83.0015, source: .song))
        XCTAssertTrue(top.offersFindAgain)
    }

    /// A map song's tempo is its median, which isn't what the grid follows, so the beats head it.
    func testASongWithABeatMapOpensOnTheBeats() {
        let top = TempoSheetTop(draft: nil, isListening: false, hasBeatMap: true, songBPM: 120)
        XCTAssertEqual(top, .beats)
        XCTAssertNil(top.shown)
        XCTAssertTrue(top.offersFindAgain)
    }

    func testATempoChosenInTheSheetHeadsIt() {
        let tapped = TempoDraft(bpm: 89, source: .tapped)
        let top = TempoSheetTop(draft: tapped, isListening: false, hasBeatMap: true, songBPM: 120)
        XCTAssertEqual(top.shown, tapped)
        XCTAssertTrue(top.offersFindAgain)
    }

    /// Finding the tempo again on its own estimate would read the same.
    func testAnEstimateDoesNotOfferFindingItAgain() {
        let top = TempoSheetTop(draft: estimate(83), isListening: false, hasBeatMap: false, songBPM: nil)
        XCTAssertFalse(top.offersFindAgain)
    }

    func testListeningHeadsTheSheetWhateverWasShown() {
        let top = TempoSheetTop(draft: estimate(83), isListening: true, hasBeatMap: false, songBPM: 90)
        XCTAssertEqual(top, .listening)
        XCTAssertFalse(top.offersFindAgain)
    }
}
