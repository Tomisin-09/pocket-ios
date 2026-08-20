import AVFoundation
import XCTest
@testable import Pocket

/// Rewriting a take down to a span of itself (ADR 0174) — the destructive half.
///
/// The load-bearing tests here are the **failure** ones. A trim cannot be undone and a take has no
/// source to regenerate from, so the property that matters is not "a good trim produces the right
/// length" but "a bad trim leaves the take exactly as it was". Every throwing path is checked
/// against the original file's length *and* its bytes.
///
/// These write into the real recordings directory, because that is what `RecordingStore.url(for:)`
/// resolves and the whole point is to exercise the in-place replace. Every fixture is uid-named and
/// removed in teardown.
final class TakeTrimmerTests: XCTestCase {

    private var written: [String] = []

    override func tearDownWithError() throws {
        for fileName in written { try? RecordingStore.delete(fileName: fileName) }
        written = []
    }

    // MARK: - Fixtures

    /// Write a silent take of `seconds` in the same AAC format the recorder uses, and return its
    /// leaf filename. Silence is fine — every assertion here reads headers and lengths, not samples.
    private func makeTake(seconds: Double) throws -> String {
        let fileName = RecordingStore.fileName(for: UUID())
        let url = try RecordingStore.url(for: fileName)
        written.append(fileName)

        let file = try AVAudioFile(forWriting: url, settings: TakeRecorder.settings)
        let format = file.processingFormat
        let frames = AVAudioFrameCount(format.sampleRate * seconds)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        try file.write(from: buffer)
        return fileName
    }

    private func duration(of fileName: String) throws -> TimeInterval {
        let url = try RecordingStore.url(for: fileName)
        let file = try AVAudioFile(forReading: url)
        return Double(file.length) / file.processingFormat.sampleRate
    }

    private func bytes(of fileName: String) throws -> Data {
        try Data(contentsOf: RecordingStore.url(for: fileName))
    }

    // MARK: - A trim that works

    func testTrimmingKeepsTheRequestedSpan() throws {
        let fileName = try makeTake(seconds: 3)
        let trimmed = try TakeTrimmer.trim(fileName: fileName, from: 1, to: 2)

        XCTAssertEqual(trimmed, 1, accuracy: TakeTrimmerTests.tolerance,
                       "the returned length is the span that was asked for")
        XCTAssertEqual(try duration(of: fileName), trimmed, accuracy: 1e-6,
                       "and it is what the file on disk actually holds")
    }

    /// The file is replaced **in place**: same leaf name, so the `Recording` row's `fileName`, its
    /// owner relationship and its Journal row all still resolve after a trim.
    func testTrimmingReplacesTheFileUnderTheSameName() throws {
        let fileName = try makeTake(seconds: 3)
        _ = try TakeTrimmer.trim(fileName: fileName, from: 0.5, to: 2.5)

        XCTAssertTrue(RecordingStore.filesOnDisk().contains(fileName),
                      "the take keeps its identity through a trim")
    }

    /// A trim reclaims disk — the reason it is destructive rather than a stored in/out span.
    func testTrimmingShrinksTheFile() throws {
        let fileName = try makeTake(seconds: 6)
        let before = try XCTUnwrap(RecordingStore.fileSize(fileName: fileName))
        _ = try TakeTrimmer.trim(fileName: fileName, from: 0, to: 1)
        let after = try XCTUnwrap(RecordingStore.fileSize(fileName: fileName))

        XCTAssertLessThan(after, before, "trimming five of six seconds must cost less on disk")
    }

    func testTrimmingLeavesNoTemporaryFileBehind() throws {
        let fileName = try makeTake(seconds: 3)
        _ = try TakeTrimmer.trim(fileName: fileName, from: 1, to: 2)

        XCTAssertFalse(RecordingStore.filesOnDisk().contains { $0.contains("trimtmp") },
                       "the temp file is consumed by the replace, not stranded next to the take")
    }

    // MARK: - Failures leave the take alone

    /// The test this file exists for. A span covering no frames throws — and the original take is
    /// still there, still its original length, byte for byte.
    func testAnEmptySpanThrowsAndLeavesTheTakeUntouched() throws {
        let fileName = try makeTake(seconds: 3)
        let lengthBefore = try duration(of: fileName)
        let bytesBefore = try bytes(of: fileName)

        XCTAssertThrowsError(try TakeTrimmer.trim(fileName: fileName, from: 1, to: 1))

        XCTAssertEqual(try duration(of: fileName), lengthBefore, accuracy: 1e-9,
                       "a refused trim costs the take nothing")
        XCTAssertEqual(try bytes(of: fileName), bytesBefore,
                       "and does not rewrite a single byte of it")
    }

    /// A span that starts past the end of the audio covers no frames either.
    func testASpanPastTheEndThrowsAndLeavesTheTakeUntouched() throws {
        let fileName = try makeTake(seconds: 3)
        let bytesBefore = try bytes(of: fileName)

        XCTAssertThrowsError(try TakeTrimmer.trim(fileName: fileName, from: 10, to: 12))

        XCTAssertEqual(try bytes(of: fileName), bytesBefore)
    }

    func testAnInvertedSpanThrowsAndLeavesTheTakeUntouched() throws {
        let fileName = try makeTake(seconds: 3)
        let bytesBefore = try bytes(of: fileName)

        XCTAssertThrowsError(try TakeTrimmer.trim(fileName: fileName, from: 2, to: 1),
                             "the trimmer does not order its own span — `TakeTrim.span` does that")

        XCTAssertEqual(try bytes(of: fileName), bytesBefore)
    }

    func testAMissingTakeThrows() {
        let fileName = RecordingStore.fileName(for: UUID())
        XCTAssertThrowsError(try TakeTrimmer.trim(fileName: fileName, from: 0, to: 1))
    }

    /// A file that isn't audio can't be trimmed, and the attempt must not leave a temp beside it.
    func testAFileThatIsNotAudioThrows() throws {
        let fileName = RecordingStore.fileName(for: UUID())
        written.append(fileName)
        try Data("not audio".utf8).write(to: RecordingStore.url(for: fileName))

        XCTAssertThrowsError(try TakeTrimmer.trim(fileName: fileName, from: 0, to: 1))
        XCTAssertFalse(RecordingStore.filesOnDisk().contains { $0.contains("trimtmp") })
    }

    // MARK: - The pure frame range

    func testFrameRangeCoversTheSpan() {
        let range = TakeTrimmer.frameRange(start: 1, end: 2, totalFrames: 132_300, sampleRate: 44_100)
        XCTAssertEqual(range.start, 44_100)
        XCTAssertEqual(range.frameCount, 44_100)
    }

    /// The off-by-one that would clip a take's last moment: a span running to the exact end keeps
    /// every frame to the end, and never asks for one past it.
    func testFrameRangeToTheExactEndKeepsEveryRemainingFrame() {
        let total = 132_300
        let range = TakeTrimmer.frameRange(start: 2, end: 3, totalFrames: total, sampleRate: 44_100)
        XCTAssertEqual(range.start + range.frameCount, total)
    }

    func testFrameRangeClampsPastTheEnd() {
        let total = 132_300
        let range = TakeTrimmer.frameRange(start: 1, end: 99, totalFrames: total, sampleRate: 44_100)
        XCTAssertEqual(range.start + range.frameCount, total)
    }

    func testFrameRangeOfAnInvertedSpanIsEmpty() {
        let range = TakeTrimmer.frameRange(start: 2, end: 1, totalFrames: 132_300, sampleRate: 44_100)
        XCTAssertEqual(range.frameCount, 0)
    }

    func testFrameRangeOfAnEmptyFileIsEmpty() {
        let range = TakeTrimmer.frameRange(start: 0, end: 1, totalFrames: 0, sampleRate: 44_100)
        XCTAssertEqual(range.frameCount, 0)
    }

    /// AAC pads and aligns to its own frame size, so a written span never lands exactly on the
    /// request. This is the same order of slack the trimmer itself verifies against.
    private static let tolerance: TimeInterval = 0.25
}
