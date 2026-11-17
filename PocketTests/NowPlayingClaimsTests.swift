import XCTest
@testable import Pocket

/// Who owns the lock screen when producers overlap (ADR 0303). The overlap is real: a routine starts the
/// incoming block before it tears down the outgoing one (ADR 0129, bug 1), and a take or a loop starts
/// over the song screen's claim. When each producer cleared the global info on its way out, the outgoing
/// block blanked the incoming one, and the incoming audio had no lock-screen control at all.
final class NowPlayingClaimsTests: XCTestCase {

    private func state(_ title: String, playing: Bool = true) -> NowPlayingState {
        NowPlayingState(title: title, artist: "", duration: 0, elapsedTime: 0, isPlaying: playing, speed: 1)
    }

    // MARK: - NowPlayingClaims

    /// The routine hand-over: the incoming block claims and pushes while the outgoing one still holds a
    /// claim; the outgoing letting go must leave the incoming block on the lock screen.
    func testTheOutgoingBlockLettingGoLeavesTheIncomingOneShowing() {
        var claims = NowPlayingClaims<String>()
        claims.claim("outgoing")
        XCTAssertEqual(claims.update("outgoing", to: state("Scale run")), .show(state("Scale run")))
        claims.claim("incoming")
        XCTAssertEqual(claims.update("incoming", to: state("Chorus riff")), .show(state("Chorus riff")))

        XCTAssertEqual(claims.release("outgoing"), .unchanged)
        XCTAssertEqual(claims.owner, "incoming")
    }

    /// A producer underneath keeps its state but doesn't draw over the one on top.
    func testAnUpdateFromUnderneathIsKeptNotShown() {
        var claims = NowPlayingClaims<String>()
        claims.claim("song screen")
        _ = claims.update("song screen", to: state("Red Moon"))
        claims.claim("take")
        _ = claims.update("take", to: state("Take"))

        XCTAssertEqual(claims.update("song screen", to: state("Red Moon", playing: false)), .unchanged)
        // …and it is what comes back when the take lets go.
        XCTAssertEqual(claims.release("take"), .show(state("Red Moon", playing: false)))
        XCTAssertEqual(claims.owner, "song screen")
    }

    func testTheLastClaimGoingClearsTheLockScreen() {
        var claims = NowPlayingClaims<String>()
        claims.claim("metronome")
        _ = claims.update("metronome", to: state("Metronome"))
        XCTAssertEqual(claims.release("metronome"), .clear)
        XCTAssertNil(claims.owner)
        XCTAssertTrue(claims.isEmpty)
    }

    /// The claim beneath has pushed nothing yet: clear, rather than leave the producer that just went.
    func testHandingBackToAClaimWithNothingPushedClears() {
        var claims = NowPlayingClaims<String>()
        claims.claim("beneath")
        claims.claim("top")
        _ = claims.update("top", to: state("Top"))
        XCTAssertEqual(claims.release("top"), .clear)
        XCTAssertEqual(claims.owner, "beneath")
    }

    /// An update arriving after its producer let go (a playhead tick, say) can't bring the session back.
    func testAProducerWithNoClaimChangesNothing() {
        var claims = NowPlayingClaims<String>()
        XCTAssertEqual(claims.update("gone", to: state("Gone")), .unchanged)
        XCTAssertEqual(claims.release("gone"), .unchanged)
        claims.claim("live")
        _ = claims.update("live", to: state("Live"))
        XCTAssertEqual(claims.update("gone", to: state("Gone")), .unchanged)
        XCTAssertEqual(claims.owner, "live")
    }

    /// The metronome claims on every start: claiming again moves it back to the top, once, with a fresh
    /// session rather than the state it held before.
    func testClaimingAgainMovesToTheTopWithAFreshSession() {
        var claims = NowPlayingClaims<String>()
        claims.claim("metronome")
        _ = claims.update("metronome", to: state("Metronome"))
        claims.claim("take")
        claims.claim("metronome")
        XCTAssertEqual(claims.owner, "metronome")

        // Moved, not duplicated: one release takes it off entirely.
        XCTAssertEqual(claims.release("metronome"), .clear)   // the take never pushed
        XCTAssertEqual(claims.owner, "take")
        XCTAssertEqual(claims.release("take"), .clear)
        XCTAssertTrue(claims.isEmpty)
    }

    // MARK: - PlayClock

    func testThePlayClockCountsOnlySoundingTime() {
        var clock = PlayClock()
        XCTAssertEqual(clock.elapsed(at: 100), 0)
        clock.run(at: 100)
        XCTAssertEqual(clock.elapsed(at: 110), 10, accuracy: 1e-9)
        clock.hold(at: 110)
        XCTAssertEqual(clock.elapsed(at: 500), 10, accuracy: 1e-9)   // held: the pause isn't counted
        clock.run(at: 500)
        XCTAssertEqual(clock.elapsed(at: 505), 15, accuracy: 1e-9)
    }

    /// Running while running mustn't move the anchor (which would lose time), and holding while held
    /// mustn't bank anything twice.
    func testThePlayClockIgnoresARepeatedRunOrHold() {
        var clock = PlayClock()
        clock.run(at: 0)
        clock.run(at: 8)
        XCTAssertEqual(clock.elapsed(at: 10), 10, accuracy: 1e-9)
        clock.hold(at: 10)
        clock.hold(at: 20)
        XCTAssertEqual(clock.elapsed(at: 30), 10, accuracy: 1e-9)
        clock.reset()
        XCTAssertEqual(clock.elapsed(at: 30), 0)
    }

    // MARK: - NowPlayingLabel

    func testALoopIsNamedOverItsSongAndArtist() {
        XCTAssertEqual(NowPlayingLabel.loop(named: "Chorus riff", songTitle: "Red Moon", artist: "Tom Misch"),
                       NowPlayingLabel(title: "Chorus riff", subtitle: "Red Moon · Tom Misch"))
        XCTAssertEqual(NowPlayingLabel.loop(named: "", songTitle: "Red Moon", artist: ""),
                       NowPlayingLabel(title: "Loop", subtitle: "Red Moon"))
        XCTAssertEqual(NowPlayingLabel.loop(named: "Intro", songTitle: nil, artist: nil),
                       NowPlayingLabel(title: "Intro", subtitle: ""))
    }
}

/// The same rules through the real hub, `MPNowPlayingInfoCenter` and all: the lock screen's commands
/// reach whoever is on top, and the hand-over leaves the incoming producer showing. The hub is
/// process-global, so nothing here assumes it starts empty: another test's claim may sit beneath.
@MainActor
final class NowPlayingHubTests: XCTestCase {

    /// What the producers heard. A class, so `@MainActor` closures (inferred `@Sendable`) can append.
    private final class Heard { var lines: [String] = [] }

    private func state(_ title: String) -> NowPlayingState {
        NowPlayingState(title: title, artist: "", duration: 0, elapsedTime: 0, isPlaying: true, speed: 1)
    }

    private func producer(_ name: String, into heard: Heard) -> NowPlayingController {
        let controller = NowPlayingController()
        controller.activate(onPlay: { heard.lines.append("\(name) play") },
                            onPause: { heard.lines.append("\(name) pause") },
                            onToggle: { heard.lines.append("\(name) toggle") })
        return controller
    }

    func testCommandsReachWhoeverIsOnTopAndTheHandOverKeepsTheIncomingShowing() {
        let heard = Heard()
        let outgoing = producer("outgoing", into: heard)
        outgoing.update(state("Scale run"))
        let incoming = producer("incoming", into: heard)
        incoming.update(state("Chorus riff"))
        XCTAssertEqual(NowPlayingHub.shared.shownTitle, "Chorus riff")

        XCTAssertTrue(NowPlayingHub.shared.perform(.pause))
        outgoing.teardown()
        XCTAssertEqual(NowPlayingHub.shared.shownTitle, "Chorus riff",
                       "the outgoing block letting go must not blank the incoming one")
        XCTAssertTrue(NowPlayingHub.shared.perform(.play))
        XCTAssertEqual(heard.lines, ["incoming pause", "incoming play"])

        incoming.teardown()
        XCTAssertNotEqual(NowPlayingHub.shared.shownTitle, "Chorus riff", "a producer that let go isn't shown")
        NowPlayingHub.shared.perform(.toggle)
        XCTAssertEqual(heard.lines, ["incoming pause", "incoming play"], "nor does it hear the lock screen")
    }

    /// A late push from a producer that already let go (a playhead tick after stop) brings nothing back.
    func testAPushAfterLettingGoIsIgnored() {
        let heard = Heard()
        let take = producer("take", into: heard)
        take.update(state("Take"))
        take.teardown()
        take.update(state("Take"))
        XCTAssertNotEqual(NowPlayingHub.shared.shownTitle, "Take")
    }
}
