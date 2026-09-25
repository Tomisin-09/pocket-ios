import XCTest
@testable import Pocket

/// The first-song walkthrough's rules (ADR 0149, as amended): three beats that tick on real actions
/// in any order, one ceremony ever, an offer for experienced players, and the words it uses.
final class SongWalkthroughTests: XCTestCase {

    private func started(ceremonySeen: Bool = false) -> SongWalkthrough {
        SongWalkthrough(entry: .started, ceremonyAlreadyShown: ceremonySeen)
    }

    // MARK: - The beats

    func testStartsOnLoopItWithNothingTicked() {
        let walkthrough = started()
        XCTAssertEqual(walkthrough.phase, .running(.loopIt))
        XCTAssertTrue(walkthrough.completed.isEmpty)
    }

    /// The path the card is written for: loop, slow, keep — and the ceremony lands on the third.
    func testTheThreeBeatsInOrderEndInTheCeremony() {
        var walkthrough = started()
        XCTAssertFalse(walkthrough.record(.spanClosed))
        XCTAssertEqual(walkthrough.phase, .running(.slowIt))
        XCTAssertFalse(walkthrough.record(.speedChanged(to: 0.5)))
        XCTAssertEqual(walkthrough.phase, .running(.keepIt))
        XCTAssertTrue(walkthrough.record(.loopSaved), "The first loop kept is the one marked moment")
        XCTAssertEqual(walkthrough.phase, .ceremony)
        walkthrough.dismissCeremony()
        XCTAssertEqual(walkthrough.phase, .finished)
    }

    /// Saving before slowing is a kept loop, not a mistake. The ceremony still marks it, and the card
    /// then goes back to the beat that is still outstanding rather than asking for it twice.
    func testKeepingBeforeSlowingStillMarksTheMomentThenAsksForTheSlowDown() {
        var walkthrough = started()
        walkthrough.record(.spanClosed)
        XCTAssertTrue(walkthrough.record(.loopSaved))
        XCTAssertEqual(walkthrough.phase, .ceremony)
        walkthrough.dismissCeremony()
        XCTAssertEqual(walkthrough.phase, .running(.slowIt))
        walkthrough.record(.speedChanged(to: 0.75))
        XCTAssertEqual(walkthrough.phase, .finished)
    }

    /// A saved loop is a loop, whichever route made it — beat 1 is true of it.
    func testASavedLoopTicksLoopItToo() {
        var walkthrough = started()
        walkthrough.record(.loopSaved)
        XCTAssertTrue(walkthrough.completed.isSuperset(of: [.loopIt, .keepIt]))
    }

    /// Slowing first is fine too: the tick is true, and the card simply asks for the loop next.
    func testSlowingFirstTicksSlowItAndLeavesLoopItCurrent() {
        var walkthrough = started()
        walkthrough.record(.speedChanged(to: 0.6))
        XCTAssertEqual(walkthrough.completed, [.slowIt])
        XCTAssertEqual(walkthrough.phase, .running(.loopIt))
    }

    /// "About half" is a suggestion with the musician's discretion attached (0149 §1). Any real step
    /// below full speed is the beat done; demanding 0.5× would be a grade. Speeding up is not.
    func testAnySlowDownCountsAndASpeedUpDoesNot() {
        var walkthrough = started()
        walkthrough.record(.speedChanged(to: 1.25))
        walkthrough.record(.speedChanged(to: 1.0))
        XCTAssertFalse(walkthrough.completed.contains(.slowIt))
        walkthrough.record(.speedChanged(to: 0.95))
        XCTAssertTrue(walkthrough.completed.contains(.slowIt))
    }

    // MARK: - One ceremony, ever (0149 §5)

    func testTheCeremonyNeverRepeatsWithinARun() {
        var walkthrough = started()
        XCTAssertTrue(walkthrough.record(.loopSaved))
        walkthrough.dismissCeremony()
        XCTAssertFalse(walkthrough.record(.loopSaved))
        XCTAssertNotEqual(walkthrough.phase, .ceremony)
    }

    /// A re-entry from Help walks the same beats and ticks them silently.
    func testARunAfterTheCeremonyWasSeenTicksSilently() {
        var walkthrough = started(ceremonySeen: true)
        walkthrough.record(.spanClosed)
        walkthrough.record(.speedChanged(to: 0.5))
        XCTAssertFalse(walkthrough.record(.loopSaved))
        XCTAssertEqual(walkthrough.phase, .finished)
    }

    // MARK: - Offered, not started (0149 §4)

    func testAnOfferIgnoresEverythingUntilAccepted() {
        var walkthrough = SongWalkthrough(entry: .offered, ceremonyAlreadyShown: false)
        XCTAssertEqual(walkthrough.phase, .offered)
        XCTAssertFalse(walkthrough.record(.loopSaved))
        XCTAssertTrue(walkthrough.completed.isEmpty)
        walkthrough.accept()
        XCTAssertEqual(walkthrough.phase, .running(.loopIt))
    }

    /// The top two intake answers are "substantial experience"; the bottom two, and anyone who
    /// skipped the question, get it started.
    func testEntryFollowsTheIntakesExperienceAnswer() {
        XCTAssertEqual(SongWalkthrough.entry(for: .justStarting), .started)
        XCTAssertEqual(SongWalkthrough.entry(for: .fewChords), .started)
        XCTAssertEqual(SongWalkthrough.entry(for: .comfortable), .offered)
        XCTAssertEqual(SongWalkthrough.entry(for: .aWhile), .offered)
        XCTAssertEqual(SongWalkthrough.entry(for: nil), .started)
    }

    // MARK: - The words (0149 §6, §7)

    /// Each beat points at the catalog instead of explaining itself — so each link must land on a
    /// question that is really there. Rewording an answer's question breaks this, not a link.
    func testEveryBeatLinksToARealHelpAnswer() {
        for beat in SongWalkthrough.Beat.allCases {
            XCTAssertNotNil(beat.helpEntry, "\(beat) links to a question not in FAQEntry.all: \(beat.helpQuestion)")
        }
    }

    /// The copy is the app's voice: it says Red Moon, never the internal name, and never praises or
    /// scores playing (ADR 0070).
    func testTheCopyNeverGradesAndNeverSaysPocket() {
        let stages: [StarterTrackScript.Stage] = [.leadIn, .heldAtStart, .awaitingEnd, .heldAtEnd]
        var copy = SongWalkthrough.Beat.allCases.flatMap { [$0.title, $0.instruction, $0.helpLinkTitle] }
        copy += stages.flatMap { [$0.instruction(isPlaying: true), $0.instruction(isPlaying: false)] }
            .compactMap { $0 }
        copy += [SongWalkthrough.offerTitle, SongWalkthrough.offerBody, SongWalkthrough.ceremonyTitle,
                 SongWalkthrough.ceremonyBody(songTitle: "Binta")]
        let hints: [StarterTrackHints.Hint] = [.click, .backingTrack]    // ADR 0220 D4
        copy += hints.flatMap { [$0.title, $0.body(loopName: "Loop 1"), $0.dismissLabel] }
        for line in copy {
            XCTAssertFalse(line.contains("Pocket"), line)
            for word in ["great", "well done", "perfect", "nice work", "score", "accurate"] {
                XCTAssertFalse(line.lowercased().contains(word), "\"\(word)\" grades: \(line)")
            }
        }
    }

    /// "Press play" is wrong advice to someone already listening.
    func testTheLeadInOnlySaysPressPlayWhilePaused() throws {
        let paused = try XCTUnwrap(StarterTrackScript.Stage.leadIn.instruction(isPlaying: false))
        let playing = try XCTUnwrap(StarterTrackScript.Stage.leadIn.instruction(isPlaying: true))
        XCTAssertTrue(paused.hasPrefix("Press play."))
        XCTAssertFalse(playing.contains("Press play"))
        XCTAssertNil(StarterTrackScript.Stage.finished.instruction(isPlaying: true))
    }

    func testTheCeremonyNamesTheSong() {
        XCTAssertTrue(SongWalkthrough.ceremonyBody(songTitle: "Binta").contains("Saved to Binta"))
    }
}
