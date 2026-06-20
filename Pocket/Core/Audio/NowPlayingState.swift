import Foundation

/// A pure description of what the lock screen / Control Center should show for
/// the current practice session. Kept free of MediaPlayer (and any UI framework)
/// so the rate/elapsed logic stays unit-testable; `NowPlayingController` maps it
/// onto `MPNowPlayingInfoCenter`. See ADR 0025.
struct NowPlayingState: Equatable {

    /// Song title — the primary line on the lock screen.
    var title: String
    /// Artist — the secondary line; omitted from the info dict when blank.
    var artist: String
    /// Full song length (seconds). The system draws the scrubber against this.
    var duration: TimeInterval
    /// Current playhead (seconds). Pushed at each transport event; the system
    /// extrapolates the clock between pushes using `reportedRate`.
    var elapsedTime: TimeInterval
    /// Whether playback is currently running.
    var isPlaying: Bool
    /// The playback speed multiplier (pitch-preserving). Drives both the reported
    /// rate and how fast the lock-screen clock advances at reduced/raised speeds.
    var speed: Double

    /// The rate the Now Playing center reports: the speed multiplier while
    /// playing, `0` when paused. Reporting `0` freezes the lock-screen clock and
    /// flips the control to the play glyph; reporting `speed` (not a hard `1`)
    /// keeps the extrapolated clock in step with reduced/raised practice speeds.
    var reportedRate: Double { isPlaying ? speed : 0 }
}
