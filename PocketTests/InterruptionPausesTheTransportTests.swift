import AVFoundation
import XCTest
@testable import Pocket

/// **An interruption pauses the transport** (ADR 0323), and so does the output going away (D4). A call, Siri or another app's audio stops Red
/// Moon's audio without telling the engine, and until 0323 every transport went on reading as playing:
/// ■ lit over silence, and the Metronome's and the loop modes' practice-log counts running on.
///
/// These post the notification the system posts, so they run the observer, the engine's own handling
/// and the owner's transport together. Nothing here can make a real interruption, so whether the audio
/// actually comes back after one is the device pass's.
///
/// **Isolation note** (as `PracticeAudioEngineTests`): `@MainActor` on the methods, not the class, so
/// the nonisolated `setUp` can make the scratch directory.
final class InterruptionPausesTheTransportTests: XCTestCase {

    private var scratch: URL!

    override func setUpWithError() throws {
        scratch = URL.temporaryDirectory.appending(path: "InterruptionTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: scratch, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: scratch)
    }

    // MARK: - Helpers

    private func post(_ type: AVAudioSession.InterruptionType) {
        NotificationCenter.default.post(name: AVAudioSession.interruptionNotification,
                                        object: AVAudioSession.sharedInstance(),
                                        userInfo: [AVAudioSessionInterruptionTypeKey: type.rawValue])
    }

    private func route(_ reason: AVAudioSession.RouteChangeReason) {
        NotificationCenter.default.post(name: AVAudioSession.routeChangeNotification,
                                        object: AVAudioSession.sharedInstance(),
                                        userInfo: [AVAudioSessionRouteChangeReasonKey: reason.rawValue])
    }

    /// The observer runs on the main queue, which may be after `post` returns: wait for it, briefly.
    @MainActor
    private func eventually(_ condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    /// Long enough to still be playing when the test reads it.
    @MainActor
    private func loadedEngine() async throws -> PracticeAudioEngine {
        let url = scratch.appending(path: "silence-\(UUID().uuidString).caf")
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1))
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100 * 20))
        buffer.frameLength = buffer.frameCapacity
        try file.write(from: buffer)
        let engine = PracticeAudioEngine()
        try await engine.load(url: url)
        return engine
    }

    // MARK: - The observer

    /// A beginning calls back; an ending doesn't, because nothing resumes by itself (D2); and letting
    /// the observer go stops it, which is what lets an engine hold one without a `deinit` of its own.
    @MainActor
    func testTheObserverHearsABeginningOnlyAndOnlyWhileKept() async {
        let began = Count()
        var observer: AudioInterruptionObserver? = AudioInterruptionObserver { began.value += 1 }
        XCTAssertNotNil(observer)

        post(.ended)
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(began.value, 0, "an interruption ending is not a beginning")

        post(.began)
        await eventually { began.value == 1 }
        XCTAssertEqual(began.value, 1)

        observer = nil
        post(.began)
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(began.value, 1, "a released observer hears nothing")
    }

    /// Headphones coming out is a cut (D4): Apple asks a player to pause rather than carry on out of the
    /// speaker. Headphones going **in**, or the category changing for a take, isn't.
    @MainActor
    func testTheOutputGoingAwayIsACutAndOtherRouteChangesAreNot() async {
        let cuts = Count()
        let observer = AudioInterruptionObserver { cuts.value += 1 }
        defer { withExtendedLifetime(observer) {} }

        route(.newDeviceAvailable)
        route(.categoryChange)
        try? await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(cuts.value, 0, "a device arriving, or a take's category change, cuts nothing")

        route(.oldDeviceUnavailable)
        await eventually { cuts.value == 1 }
        XCTAssertEqual(cuts.value, 1, "headphones coming out pauses the transport")
    }

    // MARK: - The song player's engine

    /// The song player, the loop trainer, Active listening, Improvise and the play-along all play
    /// through this engine. It pauses itself, so `isPlaying` falls, `onPlayingChange` fires (which is
    /// what stops the song player's count, ADR 0322) and the owner is told.
    @MainActor
    func testThePracticeEnginePausesAndTellsItsOwner() async throws {
        let engine = try await loadedEngine()
        defer { engine.stop() }
        var told = 0
        var flips = 0
        engine.onInterrupted = { told += 1 }

        engine.play()
        XCTAssertTrue(engine.isPlaying)
        engine.onPlayingChange = { flips += 1 }

        post(.began)
        await eventually { !engine.isPlaying }
        XCTAssertFalse(engine.isPlaying, "■ must not stay lit over silence")
        XCTAssertEqual(flips, 1, "the pause is the ordinary one, so the practice log's count hears it")
        XCTAssertEqual(told, 1)

        engine.play()
        XCTAssertTrue(engine.isPlaying, "▶ plays again after the interruption")
    }

    /// With nothing playing, nothing on screen changes, and the owner is still told: a slice for Name
    /// the notes sounds with the transport stopped, and only its owner can cut it.
    @MainActor
    func testAnInterruptionWithTheTransportStoppedStillTellsTheOwner() async throws {
        let engine = try await loadedEngine()
        defer { engine.stop() }
        var told = 0
        engine.onInterrupted = { told += 1 }

        post(.began)
        await eventually { told == 1 }
        XCTAssertFalse(engine.isPlaying)
        XCTAssertEqual(told, 1)
    }

    // MARK: - The metronome's engine

    /// The Metronome, an exercise run and a freeform block's click. An interruption is the on-screen
    /// Pause: the session clock stops, so the practice log's count (ADR 0242, the time the click
    /// sounded) stops with it, and Resume carries on from there.
    @MainActor
    func testTheMetronomePausesAndResumes() async throws {
        let engine = StandaloneMetronomeEngine()
        defer { engine.stop() }

        engine.start()
        XCTAssertEqual(engine.transport, .playing)

        // What the system does to the engine; the notification is what it says about it.
        engine.engine.stop()
        post(.began)
        await eventually { engine.transport != .playing }
        XCTAssertEqual(engine.transport, .paused, "an interruption pauses; it doesn't stop and zero the sitting")
        let banked = engine.elapsed
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(engine.elapsed, banked, "a paused click's time doesn't run on")

        engine.resume()
        XCTAssertEqual(engine.transport, .playing)
        XCTAssertTrue(engine.engine.isRunning,
                      "a resume restarts the engine the interruption stopped, or Resume lights silence")
    }
}

/// A count the observer's main-actor closure can write to: a captured `var` can't be, under Swift 6.
@MainActor
private final class Count {
    var value = 0
}
