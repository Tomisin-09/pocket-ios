import Foundation

/// The Metronome screen's practice-log clock (ADR 0242): when the click started, and — when it ends —
/// the run to log.
///
/// **On the screen, never in the engine.** `StandaloneMetronomeEngine` also drives an exercise run and
/// a freeform block, which already log themselves as `.exercise`, and two previews, which are not
/// practice. A clock in the engine would log every exercise twice and every preview once. The same
/// reasoning put `RampLessRunLog` on the view that knows what the run *was* rather than on what plays
/// it.
///
/// **Pure** — no SwiftUI, no SwiftData — so that a run starts only from stopped, that a pause doesn't
/// move its start, and that ending it twice logs it once are unit-tested rather than trusted. The view
/// feeds it the transport and writes what `finish` hands back.
struct MetronomeRunLog: Equatable {

    /// When the click started: the moment the transport left `.stopped`. `nil` while no run is going.
    ///
    /// Taken from the transport, not from the Start button, because the button is not the only way
    /// in — the automator's own Start starts the click when it is stopped.
    private(set) var startedAt: Date?

    /// A transport change. Only **stopped → sounding** starts a run. Pause and resume are one sitting,
    /// which is how the engine's session clock already counts them, so they leave the start alone.
    mutating func transportChanged(from old: StandaloneMetronomeEngine.Transport,
                                   to new: StandaloneMetronomeEngine.Transport,
                                   at now: Date = .now) {
        if old == .stopped, new != .stopped { startedAt = now }
    }

    /// End the run and hand back what to log: when it started, and how long the click **sounded** —
    /// pauses left out. `nil` when no run was going, which is what stops *Stop, then leave the screen*
    /// from logging the same sitting twice.
    ///
    /// The 30-second floor is not applied here. It is `PracticeLogWriter`'s, keyed by kind, so it
    /// holds for every metronome row however that row comes to be written.
    mutating func finish(soundedSeconds: TimeInterval) -> DateInterval? {
        guard let startedAt else { return nil }
        self.startedAt = nil
        return DateInterval(start: startedAt, duration: max(0, soundedSeconds))
    }
}
