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

    /// - Parameter startPercent: where the adjuster opens, in integer percent-of-original. Defaults
    ///   to the loop's own command (`loop.ramp.command`) — the tempo the player owns the passage at,
    ///   which is the right place to start *internalising* it. `ImproviseView` passes the loop's
    ///   `armingSpeed` instead: a bed plays at the record's tempo unless the loop has been measured
    ///   slower, and a section drawn at 70% to pick a lick off is a poor jam tempo by default.
    init(loop: Loop, startPercent: Int? = nil) {
        model = LoopRunModel(loop: loop)
        percent = Self.clamp(startPercent ?? loop.ramp.command)
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
        startTask = Task { [weak self] in
            guard let self else { return }
            await model.loadIfNeeded()
            guard !Task.isCancelled, !model.loadFailed else { return }
            model.startAudition(percent: self.percent)
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

    /// Stop playback and cancel any pending load. Idempotent — safe to call on disappear.
    func stop() {
        startTask?.cancel()
        startTask = nil
        model.stop()
    }
}
