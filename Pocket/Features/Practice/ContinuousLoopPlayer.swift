import Foundation

/// **Continuous playback of a loop's own audio** at one live-adjustable tempo — the engine behind the
/// two loop modes that have no ramp: ear training (ADR 0104) and improvising over a backing track
/// (ADR 0135). Unlike `LoopAudioPreviewPlayer` — a capped ~10 s audition for the routine block
/// preview — this keeps the loop region cycling until the player stops it, so they can listen a shape
/// into their ear or solo over it for as long as they like. It wraps a `LoopRunModel` (which owns a
/// private engine and handles region loading / looping), so neither mode ever disturbs a live run.
///
/// Named for what it does rather than for one of its callers: it was `EarTrainingPlayer` while ear
/// training was the only mode built on it, and a shared type named for one of two modes is how the
/// next reader concludes that improvising *is* ear training.
///
/// Loops are DRM-free local/iCloud files (ADR 0001), so replaying the real audio is allowed. Nothing
/// is measured or captured (ADR 0070 / 0104 E6 / 0135 B5): both modes play *to* the player and listen
/// to nothing.
@MainActor
@Observable
final class ContinuousLoopPlayer {

    /// Tempo bounds for the adjuster, integer percent-of-original — slow right down to internalise
    /// (25%) up to a touch above tempo (150%), in 5% steps. Within the engine's 25–200%.
    static let minPercent = 25
    static let maxPercent = 150
    static let step = 5

    private let model: LoopRunModel
    /// Live playback tempo as integer percent-of-original — **adjustable** while sounding (ADR 0104
    /// / 0135 B3). Slowing to internalise is the point in ear training; in improvise it's a comfort
    /// setting, which is why neither mode records it as an achievement.
    private(set) var percent: Int
    private var startTask: Task<Void, Never>?

    /// The lock screen (ADR 0303), claimed when the loop starts and held until `stop()`. Its pause is a
    /// **stop** and its play starts the loop again, because this player has two states, ▶ and ■, and the
    /// screens built on it handle exactly those: Count the notes reads `isPlaying` falling as a pass
    /// ending, and a take is finalised before the bed stops. The claim outlives a lock-screen stop, so
    /// there is still a play to press; the on-screen ■, or leaving the screen, lets it go.
    private let nowPlaying = NowPlayingController()
    /// The lock screen's clock: time spent sounding, across lock-screen stops, since the on-screen start.
    @ObservationIgnored private var clock = PlayClock()
    /// Runs before a lock-screen stop silences the loop. A host that records sets it to its take finish,
    /// so the take is finalised before the bed stops, as the on-screen ■ does it (ADR 0304).
    @ObservationIgnored var onRemoteStop: (() -> Void)?
    /// The practice log's clock (ADR 0321): how long audio has sounded on this visit — the loop, or a
    /// slice of it for Name the notes — across every stop. Not the lock screen's `clock`, which a stop
    /// resets; only `takeSoundedRun()` resets this one.
    @ObservationIgnored private var sounded = SoundedTime()
    /// An interruption (a call, another app's audio) has silenced the audio under the transport. The
    /// transport still reads as playing, its ■ up, because nothing restarts the engine after an
    /// interruption, so `isPlaying` alone would go on counting a loop nobody can hear. Cleared when the
    /// audio is stopped or starts.
    @ObservationIgnored private var silencedByInterruption = false

    /// - Parameter startPercent: where the adjuster opens, in integer percent-of-original. Defaults
    ///   to the loop's own command (`loop.ramp.command`) — the tempo the player owns the passage at,
    ///   which is the right place to start *internalising* it. `ImproviseView` passes the loop's
    ///   `armingSpeed` instead: a bed plays at the record's tempo unless the loop has been measured
    ///   slower, and a section drawn at 70% to pick a lick off is a poor jam tempo by default.
    init(loop: Loop, startPercent: Int? = nil) {
        model = LoopRunModel(loop: loop)
        percent = Self.clamp(startPercent ?? loop.ramp.command)
    }

    /// A stretch of a song rather than one loop (ADR 0289): *Watch it on the neck* for a section, or the
    /// whole song, from `start` to `end` in song seconds. It opens at the record's own tempo, since the loops
    /// in a section can each have a different command.
    init(song: Song, from start: TimeInterval, to end: TimeInterval) {
        let duration = max(song.duration, 1)
        model = LoopRunModel(song: song, start: max(0, start / duration), end: min(1, end / duration))
        percent = 100
    }

    private static func clamp(_ value: Int) -> Int { min(max(value, minPercent), maxPercent) }

    /// Nudge the tempo by one `step`, clamped — drives the −/+ controls; takes effect live if playing.
    func adjustTempo(by delta: Int) { setTempo(percent + delta) }

    /// Set the tempo to a clamped percent, applied live to the engine when sounding (ADR 0104).
    func setTempo(_ newPercent: Int) {
        percent = Self.clamp(newPercent)
        model.setAuditionPercent(percent)
    }

    var canSlowDown: Bool { percent > Self.minPercent }
    var canSpeedUp: Bool { percent < Self.maxPercent }

    /// **Another key** (ADR 0305 D3): Active listening's shift, in semitones. It starts at 0 and is never
    /// saved: this player is made per visit, with its own engine, so the shift goes when the screen does.
    /// It sits on top of the song's own shift (D1), so its range is whatever keeps the total within six:
    /// −7…+5 on a song raised by 1, still all twelve keys.
    private(set) var keyShift = 0

    /// The song's own shift (D4), which the stepper's 0 already plays at.
    var songShift: Int { model.songShift }

    /// Set the shift, held inside the range, and move the audio live. Speed doesn't change.
    func setKeyShift(_ semitones: Int) {
        keyShift = KeyShift.session(semitones, song: songShift)
        model.setSessionShift(keyShift)
    }

    var canShiftDown: Bool { keyShift > KeyShift.sessionRange(song: songShift).lowerBound }
    var canShiftUp: Bool { keyShift < KeyShift.sessionRange(song: songShift).upperBound }

    /// Whether audio is cycling — drives the play/stop glyph.
    var isPlaying: Bool { model.isRunning }
    /// True once the loop's audio couldn't be resolved (moved/deleted file) — the sheet says so
    /// rather than offering a silent dead session.
    var isUnavailable: Bool { model.loadFailed }
    /// True while the region is still resolving/loading, so the sheet can show a spinner on first play.
    var isLoading: Bool { model.isLoading }

    /// Toggle continuous playback: load the region if needed and start cycling at `percent`, or stop
    /// one already sounding. There is **no** auto-stop — internalising, and jamming, take as long as
    /// they take.
    func toggle() {
        if isPlaying { stop(); return }
        // A slice still sounding would sit ahead of the loop in the player's queue, and the loop's clock
        // would run late by what was left of it (the naming strip plays the loop, ADR 0227 D2).
        stopSlice()
        startTask = Task { [weak self] in
            guard let self else { return }
            await model.loadIfNeeded()
            guard !Task.isCancelled, !model.loadFailed else { return }
            model.startAudition(percent: self.percent)
            silencedByInterruption = false
            syncSoundedTime()
            claimLockScreen()
        }
    }

    /// A player seeded for **improvising** (ADR 0135 B3): opens at the loop's `armingSpeed` — its
    /// measured command tempo when there is one, else **full tempo** (ADR 0089's rule, reused).
    ///
    /// Deliberately *not* the ear-training seed (`ramp.command`, which falls back to the loop's stored
    /// practice `speed`): a section drawn at 70% to pick a lick off it would then open a jam at 70%,
    /// and a bed's honest default is the tempo the record plays at. A factory rather than a rule
    /// inside `init`, so the two improvise hosts can't drift apart on it.
    static func improvising(over loop: Loop) -> ContinuousLoopPlayer {
        ContinuousLoopPlayer(loop: loop, startPercent: LoopCommandRamp.percent(loop.armingSpeed))
    }

    /// How long one pass of the region takes at the current tempo — what ADR 0141's end-of-block
    /// rounding needs so a routine block never cuts a phrase.
    func cycleSeconds(for loop: Loop) -> TimeInterval {
        RampLessBlockLength.cycleSeconds(regionSeconds: loop.regionSeconds, percent: percent)
    }

    /// Stop playback, cancel any pending load, and let go of the lock screen. Idempotent — safe to call
    /// on disappear.
    func stop() {
        silence()
        nowPlaying.teardown()
        clock.reset()
    }

    /// Everything `stop()` does to the audio, without letting go of the lock screen.
    private func silence() {
        startTask?.cancel()
        startTask = nil
        sliceTask?.cancel()
        sliceTask = nil
        isSlicePlaying = false
        model.stop()
        silencedByInterruption = false
        syncSoundedTime()
    }

    // MARK: - Practice log (ADR 0321)

    /// Whether audio is actually coming out: the loop or a slice, unless an interruption has cut it.
    private var isSounding: Bool { (isPlaying || isSlicePlaying) && !silencedByInterruption }

    /// Bring the practice-log clock up to what is sounding now. Called after every change to it, so the
    /// clock follows this player's own state rather than each call site remembering to start or stop it.
    private func syncSoundedTime() {
        if isSounding {
            sounded.began(at: .now, uptime: PlayClock.now)
        } else {
            sounded.ended(uptime: PlayClock.now)
        }
    }

    /// What this visit logs: from when audio first sounded, for as long as it sounded, with every stop
    /// left out — then start over. `nil` when nothing sounded. Read by the screen that logs the run
    /// (`RampLessRunLog`, or a routine block's Done), never by this player, which doesn't know whether
    /// it is practice: *Watch it on the neck* plays one too.
    func takeSoundedRun() -> DateInterval? { sounded.take(uptime: PlayClock.now) }

    /// An audio interruption has begun. The engine has stopped under the transport; stop counting it.
    func audioWasInterrupted() {
        silencedByInterruption = true
        syncSoundedTime()
    }

    // MARK: - Lock screen (ADR 0303)

    /// Take the lock screen once the loop is actually sounding. Claiming again on every start keeps this
    /// player on top of anything that claimed while it was stopped.
    private func claimLockScreen() {
        guard isPlaying else { return }
        clock.run(at: PlayClock.now)
        nowPlaying.activate(onPlay: { [weak self] in self?.startFromLockScreen() },
                            onPause: { [weak self] in self?.stopFromLockScreen() },
                            onToggle: { [weak self] in
                                guard let self else { return }
                                if isPlaying { stopFromLockScreen() } else { startFromLockScreen() }
                            })
        pushNowPlaying()
    }

    /// The lock screen's pause: finish the host's take, then silence the loop, keeping the claim so play
    /// is still there to press.
    private func stopFromLockScreen() {
        guard isPlaying else { return }
        onRemoteStop?()
        silence()
        clock.hold(at: PlayClock.now)
        pushNowPlaying()
    }

    /// The lock screen's play: the loop starts again, as the on-screen ▶ starts it, without arming a take.
    private func startFromLockScreen() {
        guard !isPlaying else { return }
        toggle()
    }

    private func pushNowPlaying() {
        let label = model.lockScreenLabel
        nowPlaying.update(NowPlayingState(title: label.title, artist: label.subtitle, duration: 0,
                                          elapsedTime: clock.elapsed(at: PlayClock.now),
                                          isPlaying: isPlaying, speed: 1))
    }

    // MARK: - Count the notes (ADR 0225)

    /// The loop's clock at this instant, or `nil` unless it is looping. What a tap reads.
    func loopClock() -> LoopClockReading? { model.loopClock() }

    private var sliceTask: Task<Void, Never>?

    /// Whether a slice is sounding, so the naming strip can ring a phrase's notes as they play (ADR 0227
    /// D2). Falls when the slice ends on its own or is cut.
    private(set) var isSlicePlaying = false

    /// Play a moment of the song around `tap` (song seconds) at the adjuster's tempo, loading the audio
    /// first if this visit hasn't played it yet: a saved piece can be opened for naming before the loop
    /// has sounded. `then` fires when the slice ends on its own. A no-op while the loop plays.
    func playSlice(at tap: TimeInterval, then: (@MainActor @Sendable () -> Void)? = nil) {
        playSlice(from: tap, to: tap, then: then)
    }

    /// Play a **phrase**, from just before the `first` tap through the moment of the `last` (ADR 0227 D2),
    /// the way `playSlice(at:)` plays one.
    func playSlice(from first: TimeInterval, to last: TimeInterval,
                   then: (@MainActor @Sendable () -> Void)? = nil) {
        sliceTask?.cancel()
        sliceTask = Task { [weak self] in
            guard let self else { return }
            await model.loadIfNeeded()
            guard !Task.isCancelled, !model.loadFailed, !model.isRunning else { return }
            isSlicePlaying = model.playSlice(from: first, to: last, percent: percent) { [weak self] in
                self?.isSlicePlaying = false
                self?.syncSoundedTime()
                then?()
            }
            if isSlicePlaying {
                silencedByInterruption = false
                syncSoundedTime()
            }
        }
    }

    /// The slice's clock while one plays. Read in the strip's `TimelineView` leaf only (ADR 0153).
    func sliceClock() -> SliceClockReading? { model.sliceClock() }

    /// Cut a slice short.
    func stopSlice() {
        sliceTask?.cancel()
        sliceTask = nil
        isSlicePlaying = false
        model.stopSlice()
        syncSoundedTime()
    }
}
