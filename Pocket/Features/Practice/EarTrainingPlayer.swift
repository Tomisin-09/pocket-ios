import Foundation

/// Continuous **ears-only** playback of a loop's own audio for ear training (ADR 0104). Unlike
/// `LoopAudioPreviewPlayer` — a capped ~10 s audition for the routine block preview — this keeps the
/// loop region cycling until the player stops it, so they can listen a shape into their ear. It wraps
/// a `LoopRunModel` (which owns a private engine and handles region loading / looping), so ear-mode
/// never disturbs a live run.
///
/// Loops are DRM-free local/iCloud files (ADR 0001), so replaying the real audio is allowed. Nothing
/// is measured or captured (ADR 0070/0104): the mode plays *to* the player and listens to nothing.
@MainActor
@Observable
final class EarTrainingPlayer {

    /// Tempo bounds for the ear-training adjuster, integer percent-of-original — slow right down to
    /// internalise (25%) up to a touch above tempo (150%), in 5% steps. Within the engine's 25–200%.
    static let minPercent = 25
    static let maxPercent = 150
    static let step = 5

    private let model: LoopRunModel
    /// Live playback tempo as integer percent-of-original — **adjustable** while listening (ADR 0104).
    /// Seeds from the loop's owned command tempo; slowing to internalise is the whole point.
    private(set) var percent: Int
    private var startTask: Task<Void, Never>?

    init(loop: Loop) {
        model = LoopRunModel(loop: loop)
        percent = Self.clamp(loop.ramp.command)
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
    /// one already sounding. There is **no** auto-stop — internalising takes as long as it takes.
    func toggle() {
        if isPlaying { stop(); return }
        startTask = Task { [weak self] in
            guard let self else { return }
            await model.loadIfNeeded()
            guard !Task.isCancelled, !model.loadFailed else { return }
            model.startAudition(percent: self.percent)
        }
    }

    /// Stop playback and cancel any pending load. Idempotent — safe to call on disappear.
    func stop() {
        startTask?.cancel()
        startTask = nil
        model.stop()
    }
}
