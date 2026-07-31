import XCTest
@testable import Pocket

/// The shared-audio-session reference count (ADR 0129 device pass, bug 1).
///
/// The defect this pins: `stop()` deactivated the process-global `AVAudioSession` unconditionally,
/// and a routine **Skip** legitimately overlaps two producers — SwiftUI starts the incoming block's
/// engine before it tears down the outgoing one — so the outgoing `stop()` silenced the run that had
/// just begun. The symptom was a run stuck on "Counting in 4" with a live UI and no click, because a
/// non-rendering node leaves `renderSampleTime()` nil and the beat counter never advances.
final class AudioSessionLeaseTests: XCTestCase {

    func testFirstReleaseOfASingleHolderDeactivates() {
        var lease = AudioSessionLease()
        lease.retain()
        XCTAssertTrue(lease.release())
        XCTAssertEqual(lease.holders, 0)
    }

    /// The Skip hand-over, exactly: the incoming run retains while the outgoing one still holds, so
    /// the outgoing release must **not** deactivate.
    func testHandoverKeepsTheSessionActive() {
        var lease = AudioSessionLease()
        lease.retain()                 // outgoing block's engine, already playing
        lease.retain()                 // incoming block's engine starts (onAppear precedes onDisappear)
        XCTAssertFalse(lease.release(), "the outgoing engine must not deactivate a session in use")
        XCTAssertEqual(lease.holders, 1)
        XCTAssertTrue(lease.release(), "the last producer out deactivates")
        XCTAssertEqual(lease.holders, 0)
    }

    /// An unbalanced extra release is inert — a double `stop()` must never pull the session out from
    /// under a producer that is still playing.
    func testExtraReleaseIsANoOp() {
        var lease = AudioSessionLease()
        XCTAssertFalse(lease.release())
        XCTAssertEqual(lease.holders, 0)
        lease.retain()
        XCTAssertTrue(lease.release())
        XCTAssertFalse(lease.release())
        XCTAssertEqual(lease.holders, 0)
    }

    func testHoldersNeverGoNegative() {
        var lease = AudioSessionLease()
        for _ in 0..<5 { lease.release() }
        XCTAssertEqual(lease.holders, 0)
        lease.retain()
        XCTAssertEqual(lease.holders, 1)
    }
}
