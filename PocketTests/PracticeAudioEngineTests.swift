import AVFoundation
import XCTest
@testable import Pocket

/// **A transport that lights up over silence** (backlog, re-diagnosed 2026-08-12).
///
/// The defect this pins: `primeSchedule` set `scheduled = true` unconditionally, including on the
/// branch that queued nothing. With the playhead parked at the file's end and no loop running,
/// `scheduleSegment` got `count == 0` and returned early — so `play()` started a player with an
/// empty queue, lit the transport, ran the playhead timer, and made no sound. Nothing detected it,
/// because no completion callback had been scheduled either.
///
/// Two ordinary gestures reach it: scrubbing the waveform to its far-right edge
/// (`seekToFraction(1.0)`), and skipping forward inside the last increment (`TransportSkip.target`
/// clamps to `duration`). The repair is that `primeSchedule` claims `scheduled` only when something
/// was really queued, and a `play()` that finds nothing left rewinds to the top — the same reset
/// `handleReachedEnd` makes when playback reaches the end on its own.
///
/// **Isolation note.** `@MainActor` sits on the test methods and the engine helper, *not* on the
/// class. `XCTestCase.setUp`/`tearDown` are nonisolated and an override cannot add isolation its
/// superclass method lacks — so annotating the class would leave `setUp` nonisolated while making
/// `scratch` main-actor-isolated, which local Xcode compiles and CI's Xcode 16 rejects. The scratch
/// directory is plain file I/O and needs no isolation; only `PracticeAudioEngine` does.
final class PracticeAudioEngineTests: XCTestCase {

    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = URL.temporaryDirectory.appending(path: "PracticeAudioEngineTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    /// A real file of known length — silence is fine, nothing here listens to it, and the scheduler
    /// only ever reads frame counts.
    private func makeSilentFile(seconds: Double, sampleRate: Double = 44_100) throws -> URL {
        let url = scratch.appending(path: "tone-\(UUID().uuidString).caf")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1))
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let frames = AVAudioFrameCount(sampleRate * seconds)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        try file.write(from: buffer)
        return url
    }

    @MainActor
    private func loadedEngine(seconds: Double = 2) async throws -> PracticeAudioEngine {
        let engine = PracticeAudioEngine()
        try await engine.load(url: try makeSilentFile(seconds: seconds))
        return engine
    }

    /// The load-bearing case. Park the playhead exactly at the end, press play: it must rewind and
    /// actually play, not sit lit and silent at `duration`.
    @MainActor
    func testPlayingFromTheVeryEndRewindsInsteadOfPlayingSilence() async throws {
        let engine = try await loadedEngine()
        defer { engine.stop() }

        engine.seek(toSeconds: engine.duration)
        XCTAssertEqual(engine.currentTime, engine.duration, accuracy: 0.001, "parked at the end")

        engine.play()
        XCTAssertEqual(engine.currentTime, 0, accuracy: 0.001,
                       "a play with nothing left to schedule must rewind to the top")
        XCTAssertTrue(engine.isPlaying)
    }

    /// A seek past the end clamps to `duration`, so it lands on the same branch — worth pinning
    /// separately, because this is the shape `TransportSkip` produces near the end of a song.
    @MainActor
    func testPlayingAfterASeekPastTheEndRewinds() async throws {
        let engine = try await loadedEngine()
        defer { engine.stop() }

        engine.seek(toSeconds: engine.duration + 30)
        engine.play()
        XCTAssertEqual(engine.currentTime, 0, accuracy: 0.001)
        XCTAssertTrue(engine.isPlaying)
    }

    /// The control: an ordinary play from mid-file must **not** rewind. Without this the fix above
    /// would be satisfied by a `play()` that always jumped to the top.
    @MainActor
    func testPlayingFromTheMiddleKeepsItsPosition() async throws {
        let engine = try await loadedEngine()
        defer { engine.stop() }

        engine.seek(toSeconds: 1)
        engine.play()
        XCTAssertGreaterThanOrEqual(engine.currentTime, 1,
                                    "a play with audio left ahead of it starts where it was")
        XCTAssertTrue(engine.isPlaying)
    }

    /// A loop is scheduled by its own branch and doesn't care where the playhead was parked, so
    /// arming one at the end plays the region rather than rewinding to zero.
    @MainActor
    func testALoopStillPlaysWithThePlayheadParkedAtTheEnd() async throws {
        let engine = try await loadedEngine()
        defer { engine.stop() }

        engine.seek(toSeconds: engine.duration)
        engine.setLoop(start: 0.5, end: 1.5)
        engine.play()
        XCTAssertTrue(engine.isPlaying)
    }
}
