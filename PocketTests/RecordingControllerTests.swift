import XCTest
import SwiftData
@testable import Pocket

/// `RecordingController`'s **session-hold** contract (ADR 0069 amendment, 2026-08-05) — the half of
/// the Start-less record grammar that is checkable off-device. A freeform block that ticks holds the
/// record-capable session for the lifetime of the screen so the take toggle never flips the audio
/// category with a click already sounding; `holdsSession` is the flag `beginArmedTake` and
/// `stopRecording` read to leave the category alone. Getting it stuck either way is the bug: stuck
/// *on* leaves the app in `.playAndRecord` after the screen is gone, stuck *off* puts the flip back
/// under a running click.
///
/// Capture itself (permission, `AVAudioRecorder`, the take's file) is device-only, as it has been
/// since slice 0 — nothing here starts a recorder.
@MainActor
final class RecordingControllerTests: XCTestCase {

    func testFreshControllerIsIdleAndHoldsNothing() {
        let controller = RecordingController()
        XCTAssertEqual(controller.state, .idle)
        XCTAssertFalse(controller.isArmed)
        XCTAssertFalse(controller.isRecording)
        XCTAssertFalse(controller.holdsSession)
        XCTAssertFalse(controller.micDenied)
    }

    // MARK: - armIfPermitted (ADR 0179)

    /// The one thing this method exists **not** to do. A routine block with auto-start on is already
    /// running by the time a permission dialog could be answered, so `armIfPermitted` must return
    /// synchronously on an undetermined permission rather than prompting — and it must not arm, since
    /// arming without permission would start a take that captures nothing.
    ///
    /// On a simulator the mic permission is granted, so this asserts the shape that holds either way:
    /// the call returns, and the controller is never left in a state that took a session it can't use.
    func testArmIfPermittedNeverPromptsAndNeverTakesASession() {
        let controller = RecordingController()
        controller.armIfPermitted()
        XCTAssertFalse(controller.isRecording)
        // Arming touches no session — the invariant stated on `takeClaim`/`holdClaim` is that a
        // controller holds nothing while merely `.armed`.
        XCTAssertFalse(controller.holdsSession)
        if MicPermission.status == .granted {
            XCTAssertEqual(controller.state, .armed)
            XCTAssertFalse(controller.micDenied)
        } else {
            XCTAssertEqual(controller.state, .idle)
        }
    }

    /// `.onAppear` can fire more than once for one screen, and a block that re-appears must not
    /// re-arm over a take already rolling.
    func testArmIfPermittedIsANoOpUnlessIdle() {
        let controller = RecordingController()
        controller.armIfPermitted()
        let after = controller.state
        controller.armIfPermitted()
        XCTAssertEqual(controller.state, after)
        XCTAssertFalse(controller.holdsSession)
    }

    func testHoldThenReleaseReturnsTheSession() {
        let controller = RecordingController()
        controller.holdRecordSession()
        XCTAssertTrue(controller.holdsSession)
        controller.releaseRecordSession()
        XCTAssertFalse(controller.holdsSession)
    }

    /// `.onAppear` can run more than once for one screen, and `.onDisappear` fires on every exit —
    /// including the one that already released. Neither may leave the flag out of step with reality.
    func testHoldAndReleaseAreIdempotent() {
        let controller = RecordingController()
        controller.holdRecordSession()
        controller.holdRecordSession()
        XCTAssertTrue(controller.holdsSession)

        controller.releaseRecordSession()
        controller.releaseRecordSession()
        XCTAssertFalse(controller.holdsSession)
    }

    // MARK: - The discard boundary

    /// The exact line that deleted real playing: a take below the floor is discarded, file and all.
    /// The policy is unchanged and correct — what was broken is that `TakeRecorder` handed it a `0`
    /// for takes minutes long (ADR 0069 amendment). Pinned so the floor can't drift silently.
    func testATakeIsKeptOnlyOnceItClearsTheAccidentalTapFloor() {
        XCTAssertFalse(RecordingController.keepsTake(duration: 0))
        XCTAssertFalse(RecordingController.keepsTake(duration: 0.49))
        XCTAssertTrue(RecordingController.keepsTake(duration: RecordingController.minTakeDuration))
        XCTAssertTrue(RecordingController.keepsTake(duration: 12))
    }

    // MARK: - The session lease

    // `AudioPlumbing.sessionHolders` is process-global across the whole test run, so these assert on
    // **deltas** and release in teardown. Absolute assertions would make the suite order-dependent.

    /// Holding the record session leases exactly once however many times `.onAppear` fires, and gives
    /// it back however many times `.onDisappear` does.
    func testHoldingTheSessionTakesExactlyOneLease() {
        let before = AudioPlumbing.sessionHolders
        let controller = RecordingController()
        addTeardownBlock { @MainActor in controller.releaseRecordSession() }

        controller.holdRecordSession()
        XCTAssertEqual(AudioPlumbing.sessionHolders, before + 1)
        controller.holdRecordSession()
        XCTAssertEqual(AudioPlumbing.sessionHolders, before + 1, "a second hold must not lease twice")

        controller.releaseRecordSession()
        XCTAssertEqual(AudioPlumbing.sessionHolders, before)
        controller.releaseRecordSession()
        XCTAssertEqual(AudioPlumbing.sessionHolders, before, "an extra release must be inert")
    }

    /// Arming touches no session, so it must own no lease — `beginArmedTake` takes one only after its
    /// `.armed` guard passes. Pins the guard-before-retain ordering, which is what keeps the failure
    /// path balanced.
    func testBeginningATakeWhileIdleTakesNoLease() {
        let before = AudioPlumbing.sessionHolders
        let controller = RecordingController()
        controller.beginArmedTake()
        XCTAssertEqual(controller.state, .idle)
        XCTAssertEqual(AudioPlumbing.sessionHolders, before)
    }

    /// A held session survives a take: the screen owns both flips, so ending a take must not hand the
    /// category back while the click is still running. Nothing is recording here, so `stopRecording`
    /// takes its guard — which is exactly the path a stray stop would take.
    func testStoppingWithNothingRecordingLeavesAHeldSessionHeld() throws {
        let container = try ModelContainer(
            for: Exercise.self, Recording.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let controller = RecordingController()
        controller.holdRecordSession()
        controller.stopRecording(owner: .exercise(Exercise(name: "Sight-reading")),
                                 context: ModelContext(container))
        XCTAssertTrue(controller.holdsSession)
        XCTAssertEqual(controller.state, .idle)
        controller.releaseRecordSession()
    }
}
