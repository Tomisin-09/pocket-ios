import AVFoundation
import XCTest
@testable import Pocket

/// **The play-along logs the time the song sounded** (ADR 0324). It logged from **Play along** to
/// **Done**, so a routine paused on its song block and left overnight logged the night. These drive the
/// real model on the demo sample: the counting rules themselves are `SoundedTimeTests`', and what only a
/// driven run shows is that the engine's transport reaches the count, a pause and a call included.
///
/// Bounds are taken against the wall clock rather than fixed, because a sleep can overrun on a loaded
/// runner but never under-run: the time left out is at least the pause, whatever else was slow.
@MainActor
final class PlayAlongSoundedTimeTests: XCTestCase {

    private func loadedModel() async throws -> SongPlayAlongModel {
        // No imported audio, so the model renders the demo sample (`SampleToneGenerator`).
        let song = Song(title: "Binta", duration: 20,
                        ref: SongRef(id: "play-along-\(UUID().uuidString)", source: .localFile, bookmark: nil))
        let model = SongPlayAlongModel(song: song)
        await model.loadIfNeeded()
        XCTAssertFalse(model.loadFailed, "the demo sample didn't render")
        return model
    }

    func testAPauseIsLeftOutAndTheRunIsHandedBackOnce() async throws {
        let model = try await loadedModel()
        defer { model.stop() }
        XCTAssertNil(model.takeSoundedRun(), "nothing has played, so there is nothing to log")

        let began = Date()
        model.start(percent: 100, loopWholeSong: true)
        try await Task.sleep(for: .milliseconds(300))
        model.toggle()
        XCTAssertEqual(model.transport, .paused)
        try await Task.sleep(for: .milliseconds(600))
        model.toggle()
        try await Task.sleep(for: .milliseconds(300))

        let run = try XCTUnwrap(model.takeSoundedRun())
        let wall = Date().timeIntervalSince(began)
        XCTAssertGreaterThanOrEqual(run.duration, 0.55, "both stretches of playing count")
        XCTAssertLessThanOrEqual(run.duration, wall - 0.55, "the paused 0.6 s is left out")
        XCTAssertNil(model.takeSoundedRun(), "Done and the song's end can't both log it")
    }

    /// A call pauses the play-along (ADR 0323), and the time after it isn't counted.
    func testACallPausesItAndStopsTheCount() async throws {
        let model = try await loadedModel()
        defer { model.stop() }

        model.start(percent: 100, loopWholeSong: true)
        try await Task.sleep(for: .milliseconds(300))
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification,
                                        object: AVAudioSession.sharedInstance(),
                                        userInfo: [AVAudioSessionInterruptionTypeKey:
                                                    AVAudioSession.InterruptionType.began.rawValue])
        for _ in 0..<100 where model.transport == .playing {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(model.transport, .paused, "the play-along still read as playing after the call")
        let cut = Date()
        try await Task.sleep(for: .milliseconds(600))

        let run = try XCTUnwrap(model.takeSoundedRun())
        XCTAssertLessThanOrEqual(run.end, cut.addingTimeInterval(0.05), "time after the call was counted")
    }
}
