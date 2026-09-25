import XCTest
@testable import Pocket

/// The starter track's two hints (ADR 0220 D4): the click once beat 1's loop is playing, the
/// Backing track flag once the scripted loop is kept. Each is shown once, one at a time, and only
/// ever points at something that is there to use.
final class StarterTrackHintsTests: XCTestCase {

    private let chords = StarterTrack.chordsStart.seconds
    private let solo = StarterTrack.soloStart.seconds

    /// The path the hints are written for: click, then the backing track after the loop is kept.
    func testTheClickArrivesWithTheLoopAndTheBackingTrackWithTheKeep() {
        var hints = StarterTrackHints()
        XCTAssertNil(hints.showing, "Nothing to point at before a loop is playing")
        hints.loopStarted(click: .off)
        XCTAssertEqual(hints.showing, .click)
        hints.clickTurnedOn()
        XCTAssertNil(hints.showing)

        let loop = UUID()
        hints.loopKept(id: loop, start: chords, end: solo)
        XCTAssertEqual(hints.showing, .backingTrack)
        XCTAssertEqual(hints.keptLoopID, loop)
        hints.backingTrackUsed()
        XCTAssertNil(hints.showing)
        XCTAssertEqual(hints.spent, [.click, .backingTrack])
    }

    /// Shown once: dismissed, a hint does not return on the next loop.
    func testADismissedHintDoesNotComeBack() {
        var hints = StarterTrackHints()
        hints.loopStarted(click: .off)
        hints.dismiss()
        XCTAssertNil(hints.showing)
        hints.loopStarted(click: .off)
        XCTAssertNil(hints.showing, "A dismissed hint re-offered itself")
    }

    /// Nothing to point at: a player who found the click first is not told about it.
    func testAClickAlreadyRunningRetiresTheHintUnshown() {
        var hints = StarterTrackHints()
        hints.loopStarted(click: .running)
        XCTAssertNil(hints.showing)
        XCTAssertTrue(hints.spent.contains(.click))
    }

    /// Turning the click on before any loop exists counts as finding it.
    func testTurningTheClickOnEarlyMeansItIsNeverOffered() {
        var hints = StarterTrackHints()
        hints.clickTurnedOn()
        hints.loopStarted(click: .off)
        XCTAssertNil(hints.showing)
    }

    /// No grid, no click: the hint points at a click that exists, never at a tempo to set. It stays
    /// eligible, so a later loop — after a tempo is back — can still offer it.
    func testNoGridOffersNothingButLeavesTheClickEligible() {
        var hints = StarterTrackHints()
        hints.loopStarted(click: .unavailable)
        XCTAssertNil(hints.showing)
        XCTAssertTrue(hints.spent.isEmpty)
        hints.loopStarted(click: .off)
        XCTAssertEqual(hints.showing, .click)
    }

    /// One at a time: keeping the loop replaces a click hint still showing, and that one is spent.
    func testTheBackingTrackHintReplacesAClickHintStillUp() {
        var hints = StarterTrackHints()
        hints.loopStarted(click: .off)
        hints.loopKept(id: UUID(), start: chords, end: solo)
        XCTAssertEqual(hints.showing, .backingTrack)
        hints.dismiss()
        hints.loopStarted(click: .off)
        XCTAssertNil(hints.showing, "The replaced click hint came back")
    }

    /// The hint says "four bars of chords", so it is offered only for the loop the script closes.
    func testALoopKeptElsewhereIsNotCalledABed() {
        var hints = StarterTrackHints()
        hints.loopKept(id: UUID(), start: StarterTrack.barStart(5), end: chords)
        XCTAssertNil(hints.showing)
        XCTAssertNil(hints.keptLoopID)
        XCTAssertFalse(hints.spent.contains(.backingTrack), "A loop that doesn't qualify spends nothing")
    }

    /// The tolerance takes the script's own landings and a snapped handle; a tap by ear is late.
    func testTheScriptedSpanToleratesASeekButNotATapByEar() {
        XCTAssertTrue(StarterTrackHints.isScriptedSpan(start: chords, end: solo))
        XCTAssertTrue(StarterTrackHints.isScriptedSpan(start: chords + 0.001, end: solo - 0.001))
        XCTAssertFalse(StarterTrackHints.isScriptedSpan(start: chords + 0.15, end: solo),
                       "150 ms is the early edge of a tap by ear (D3)")
        XCTAssertFalse(StarterTrackHints.isScriptedSpan(start: chords, end: solo + 0.2))
    }

    /// Deleting the kept loop takes the hint with it, and a second keep does not revive it.
    func testDeletingTheKeptLoopEndsTheHint() {
        var hints = StarterTrackHints()
        hints.loopKept(id: UUID(), start: chords, end: solo)
        hints.keptLoopRemoved()
        XCTAssertNil(hints.showing)
        hints.loopKept(id: UUID(), start: chords, end: solo)
        XCTAssertNil(hints.showing, "Shown once, even for a second copy of the same loop")
    }

    /// The copy names the loop the player will hold, by whatever name it has now.
    func testTheBackingTrackHintNamesTheLoop() {
        let body = StarterTrackHints.Hint.backingTrack.body(loopName: "Chords")
        XCTAssertTrue(body.contains("Hold Chords"), body)
        XCTAssertTrue(body.contains("Backing track"), "It must name the toggle as the sheet labels it")
    }
}
