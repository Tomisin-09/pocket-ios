import XCTest
@testable import Pocket

/// The Watch-visibility rule (ADR 0077, reversing ADR 0065's always-on gating). Watch is a one-shot
/// walk-through, redundant when the board already walks continuously and essential when it doesn't.
/// The board walks continuously **only** when the animate preference is on *and* Reduce Motion is
/// off — so that's the one case Watch hides; every other case it shows (the motion-averse escape
/// hatch). Pinned because a regression here either clutters the animated common case or strands the
/// Reduce-Motion user with no way to see the shape move (AGENTS.md).
final class FretboardPlayOnceButtonTests: XCTestCase {

    func testHiddenOnlyWhenBoardWalksContinuously() {
        // Animate on + Reduce Motion off ⇒ board walks ⇒ one-shot is redundant ⇒ hide.
        XCTAssertFalse(FretboardPlayOnceButton.shouldShow(animates: true, reduceMotion: false))
    }

    func testShownWhenAnimationIsOff() {
        // The default user (animate defaults off): Watch is the only way to see it move.
        XCTAssertTrue(FretboardPlayOnceButton.shouldShow(animates: false, reduceMotion: false))
    }

    func testShownUnderReduceMotionEvenWithAnimateOn() {
        // Reduce Motion forces the board static, so Watch stays as the escape hatch.
        XCTAssertTrue(FretboardPlayOnceButton.shouldShow(animates: true, reduceMotion: true))
        XCTAssertTrue(FretboardPlayOnceButton.shouldShow(animates: false, reduceMotion: true))
    }
}
