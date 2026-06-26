import Foundation

/// Pure decision for the **song-level resume-tempo invariant** (ADR 0044): what should happen
/// to the song's working tempo when the active loop changes. Keyed only on whether a loop is
/// armed *before* and *after* the change — so the rule is unit-testable without constructing
/// the audio-backed `WaveformPracticeModel` (its `AVAudioUnitTimePitch` can't be built on a
/// headless CI runner). The model applies the returned action at its `activeLoopID` choke point.
enum SongTempoTransition: Equatable {
    /// Full song → loop (the first loop arms): bank the current `speed` as the song's resume
    /// tempo, before the loop's own speed overwrites it.
    case bankSongTempo
    /// Loop → full song (the last loop disarms): restore `speed` to the song's resume tempo, so
    /// a loop's speed never lingers as the full-song tempo.
    case restoreSongTempo
    /// Loop → loop, or no change in whether a loop is armed: leave the song's tempo alone.
    case none

    static func forActiveLoopChange(wasArmed: Bool, nowArmed: Bool) -> SongTempoTransition {
        switch (wasArmed, nowArmed) {
        case (false, true): return .bankSongTempo
        case (true, false): return .restoreSongTempo
        default: return .none
        }
    }
}
