import Foundation

/// Strum-pattern **audio preview** support for the metronome engine (ADR 0071 R5): when armed with a
/// `StrumSchedule`, the driver's tick loop plays the pattern's down/up/accent/mute rhythm as clicks
/// (rests silent) instead of the meter's default accents. Phase 1 is a *rhythm* reference — the click
/// voice has no pitch, so it conveys **when and how hard** you strum, not the chord tone (ADR 0070: an
/// audition, never a graded backing track). Split out of `StandaloneMetronomeEngine` to keep it lean.
extension StandaloneMetronomeEngine {

    /// A resolved strum pattern for the scheduler: the per-slot click levels (`nil` = a silent rest)
    /// and the sub-tick grid (`slotsPerBeat`). Built from a pure `StrumPattern.clickIntensities`, so
    /// the only audio-specific step here is mapping intensity → `ClickVoice.ClickLevel`.
    struct StrumSchedule {
        let levels: [ClickVoice.ClickLevel?]
        let ticksPerBeat: Int
    }

    /// Arm (or clear) a strum-pattern preview before `start()`. `nil` restores the normal metronome.
    /// The pattern's cycle is one bar of slots; the scheduler wraps it for the preview's duration.
    func setStrumPattern(_ pattern: StrumPattern?) {
        guard let pattern, pattern.slotCount > 0 else { strumSchedule = nil; return }
        let levels = pattern.clickIntensities.map { $0.map(Self.clickLevel) }
        strumSchedule = StrumSchedule(levels: levels, ticksPerBeat: max(1, pattern.slotsPerBeat))
    }

    /// The click level for a sub-tick, or `nil` to schedule nothing. When a strum pattern is armed it
    /// reads the pattern's slot (wrapping the bar); otherwise it's the meter default — the on-beat tick
    /// accented per the time signature, the in-between sub-ticks the quieter subdivision. A **count-in**
    /// always uses the meter default (a steady pulse to count in on), so the pattern only sounds once
    /// the drill itself begins (ADR 0071 R5 · ADR 0052).
    func scheduledLevel(forTick tickIndex: Int, ticksPerBeat: Int) -> ClickVoice.ClickLevel? {
        if let schedule = strumSchedule, !schedule.levels.isEmpty, !automatorCountingIn {
            let count = schedule.levels.count
            return schedule.levels[((tickIndex % count) + count) % count]
        }
        if tickIndex % ticksPerBeat == 0 {
            return timeSignature.isAccented(beatInBar: tickIndex / ticksPerBeat) ? .accent : .beat
        }
        return .subdivision
    }

    /// Map a pure strum intensity to the engine's click voice — accent → accent, a normal stroke →
    /// the beat click, a mute → the quieter subdivision "chuck".
    private static func clickLevel(_ intensity: StrumClickLevel) -> ClickVoice.ClickLevel {
        switch intensity {
        case .accent: return .accent
        case .stroke: return .beat
        case .mute: return .subdivision
        }
    }
}
