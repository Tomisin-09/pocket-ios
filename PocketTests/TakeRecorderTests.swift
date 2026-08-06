import AVFoundation
import XCTest
@testable import Pocket

/// `TakeRecorder`'s **duration fallback** (ADR 0069 amendment, 2026-08-05).
///
/// The defect this pins: `AVAudioRecorder.currentTime` reports `0` once the *system* has stopped the
/// recorder — a category flip that removed input from the route, a route change, an interruption —
/// and `RecordingController` read that zero as an accidental half-second tap and **deleted the
/// file**. Takes holding real playing were destroyed on stop. The repair is that a zero is never
/// trusted: the length is read back off the written file, which is what this covers.
///
/// Capture itself stays device-only (no mic in the test host). `writtenDuration(of:)` is testable
/// precisely because it is `nonisolated static` over a plain URL — that factoring is the point.
final class TakeRecorderTests: XCTestCase {

    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = URL.temporaryDirectory.appending(path: "TakeRecorderTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    /// The load-bearing case: a real file of known length reports that length, so a take the system
    /// stopped is kept rather than discarded.
    func testWrittenDurationOfAKnownFileIsItsRealLength() throws {
        let url = scratch.appending(path: "take.caf")
        let seconds = 3.0
        let sampleRate = 44_100.0
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let frames = AVAudioFrameCount(sampleRate * seconds)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames          // silence is fine — only the header is read back
        try file.write(from: buffer)

        let measured = TakeRecorder.writtenDuration(of: url)
        XCTAssertEqual(measured, seconds, accuracy: 1.0 / sampleRate,
                       "a take the system stopped must report its real length, not zero")
    }

    /// A file whose header was never finalised holds no playable audio, so `0` is the honest answer —
    /// and `0` is what makes the min-duration rule discard it, correctly this time.
    func testAFileThatIsNotAudioHasNoDuration() throws {
        let url = scratch.appending(path: "junk.m4a")
        try Data("not audio".utf8).write(to: url)
        XCTAssertEqual(TakeRecorder.writtenDuration(of: url), 0)
    }

    func testAMissingFileHasNoDuration() {
        XCTAssertEqual(TakeRecorder.writtenDuration(of: scratch.appending(path: "gone.m4a")), 0)
    }
}
