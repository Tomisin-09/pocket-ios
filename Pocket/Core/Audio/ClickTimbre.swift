import Foundation

/// The three metronome "click levels" (ADR 0043 §5): the accented bar downbeat, a plain beat,
/// and a quieter subdivision tick that sits *under* the beats rather than competing with them.
/// Moved here from `ClickVoice` so the pure timbre synthesis can name a level without pulling in
/// the audio plumbing.
enum ClickLevel: Equatable, CaseIterable { case accent, beat, subdivision }

/// A selectable metronome **timbre** (ADR 0114). The metronome's sound is fully *synthesized* PCM —
/// there are no sample assets — so a timbre is just a recipe for the three per-level click buffers
/// `ClickVoice` plays. The synthesis is pure (`[Float]` samples out, no AVFoundation), so it's
/// unit-testable and stays off the audio classes.
///
/// **Hybrid-ready** (the v2 direction): the abstraction is "a timbre supplies samples for a level,"
/// so a future case could load a bundled recording instead of synthesizing — without touching
/// `ClickVoice`. Every current case synthesizes; there are no bundled samples yet. All timbres are
/// **free** (ADR 0114): sound choice is quality-of-life, not a Red Moon Pro lever (ADR 0112).
enum ClickTimbre: String, CaseIterable, Identifiable {
    /// The original crisp digital tick — the default, byte-for-byte unchanged from before timbres
    /// existed, so an install that never chooses hears exactly what it always did.
    case click
    /// A warm, hollow wooden knock.
    case woodBlock
    /// A sharp, bright rim-style click with a noisy attack.
    case rim
    /// A clean electronic beep.
    case beep

    /// The sound shipped before this setting existed; the fallback for any install that never chose.
    static let `default`: ClickTimbre = .click

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .click: return "Click"
        case .woodBlock: return "Wood block"
        case .rim: return "Rim"
        case .beep: return "Beep"
        }
    }

    /// One-line description for the settings row.
    var blurb: String {
        switch self {
        case .click: return "The classic crisp tick."
        case .woodBlock: return "A warm, hollow knock."
        case .rim: return "A sharp, bright rim click."
        case .beep: return "A clean electronic beep."
        }
    }

    /// Mono PCM samples for one click level at `sampleRate`, bounded to [-1, 1]. Pure — the caller
    /// (`ClickVoice`) wraps the returned array in an `AVAudioPCMBuffer`.
    func samples(for level: ClickLevel, sampleRate: Double) -> [Float] {
        Self.synthesize(spec: spec(for: level), sampleRate: sampleRate)
    }

    // MARK: - Voicing

    /// The synthesis recipe for one level of one timbre.
    private struct ClickSpec {
        var frequency: Double
        var amplitude: Double
        var duration: TimeInterval
        var decay: Double        // exponential envelope rate; larger ⇒ shorter / clickier
        var waveform: Waveform
        var noiseMix: Double     // 0 pure tone … 1 pure noise (the rim's transient attack)
    }
    private enum Waveform { case sine, square }

    /// One `switch self` dispatch to a per-timbre voicing (kept small so it stays under the
    /// cyclomatic-complexity cap and each voice reads on its own).
    private func spec(for level: ClickLevel) -> ClickSpec {
        switch self {
        case .click: return Self.clickSpec(level)
        case .woodBlock: return Self.woodBlockSpec(level)
        case .rim: return Self.rimSpec(level)
        case .beep: return Self.beepSpec(level)
        }
    }

    /// Reproduces the exact pre-timbre sound: sine burst, 25 ms, decay 90 (see the old
    /// `ClickVoice.makeClick`). Do not retune — this is the unchanged default.
    private static func clickSpec(_ level: ClickLevel) -> ClickSpec {
        switch level {
        case .accent: return ClickSpec(frequency: 1_200, amplitude: 0.6,
                                       duration: 0.025, decay: 90, waveform: .sine, noiseMix: 0)
        case .beat: return ClickSpec(frequency: 900, amplitude: 0.6,
                                     duration: 0.025, decay: 90, waveform: .sine, noiseMix: 0)
        case .subdivision: return ClickSpec(frequency: 700, amplitude: 0.28,
                                            duration: 0.025, decay: 90, waveform: .sine, noiseMix: 0)
        }
    }

    /// Lower and a touch longer than the click, with a faint noise transient for the "tok".
    private static func woodBlockSpec(_ level: ClickLevel) -> ClickSpec {
        switch level {
        case .accent: return ClickSpec(frequency: 1_050, amplitude: 0.62,
                                       duration: 0.04, decay: 60, waveform: .sine, noiseMix: 0.05)
        case .beat: return ClickSpec(frequency: 820, amplitude: 0.6,
                                     duration: 0.04, decay: 60, waveform: .sine, noiseMix: 0.05)
        case .subdivision: return ClickSpec(frequency: 620, amplitude: 0.28,
                                            duration: 0.035, decay: 70, waveform: .sine, noiseMix: 0.05)
        }
    }

    /// Very short, bright, half noise — a stick-on-rim crack.
    private static func rimSpec(_ level: ClickLevel) -> ClickSpec {
        switch level {
        case .accent: return ClickSpec(frequency: 1_900, amplitude: 0.7,
                                       duration: 0.02, decay: 150, waveform: .sine, noiseMix: 0.5)
        case .beat: return ClickSpec(frequency: 1_700, amplitude: 0.6,
                                     duration: 0.02, decay: 150, waveform: .sine, noiseMix: 0.55)
        case .subdivision: return ClickSpec(frequency: 1_500, amplitude: 0.3,
                                            duration: 0.018, decay: 170, waveform: .sine, noiseMix: 0.6)
        }
    }

    /// A cleaner, more sustained electronic beep — square wave, slower decay.
    private static func beepSpec(_ level: ClickLevel) -> ClickSpec {
        switch level {
        case .accent: return ClickSpec(frequency: 1_320, amplitude: 0.45,
                                       duration: 0.05, decay: 38, waveform: .square, noiseMix: 0)
        case .beat: return ClickSpec(frequency: 990, amplitude: 0.45,
                                     duration: 0.05, decay: 38, waveform: .square, noiseMix: 0)
        case .subdivision: return ClickSpec(frequency: 780, amplitude: 0.24,
                                            duration: 0.045, decay: 45, waveform: .square, noiseMix: 0)
        }
    }

    /// Render a spec to mono float samples: a `waveform` oscillator under a fast exponential decay,
    /// optionally blended with a short deterministic noise burst. The blend is a convex combination
    /// (`(1−mix)·tone + mix·noise`), so the peak never exceeds `amplitude` and the click can't clip.
    /// `frameCount` truncates like the old `AVAudioFrameCount(duration · sampleRate)` so `.click`
    /// stays sample-identical to the pre-timbre buffer.
    private static func synthesize(spec: ClickSpec, sampleRate: Double) -> [Float] {
        let frameCount = max(0, Int(spec.duration * sampleRate))
        guard frameCount > 0 else { return [] }
        var samples = [Float](repeating: 0, count: frameCount)
        var noise = NoiseSource()
        for frame in 0..<frameCount {
            let time = Double(frame) / sampleRate
            let envelope = exp(-spec.decay * time)          // fast decay ⇒ click, not tone
            let phase = 2 * .pi * spec.frequency * time
            let tone: Double
            switch spec.waveform {
            case .sine: tone = sin(phase)
            case .square: tone = sin(phase) >= 0 ? 1 : -1
            }
            let noiseSample = spec.noiseMix > 0 ? noise.next() : 0
            let mixed = (1 - spec.noiseMix) * tone + spec.noiseMix * noiseSample
            samples[frame] = Float(mixed * envelope * spec.amplitude)
        }
        return samples
    }
}

/// A tiny deterministic white-noise source (xorshift64) so a timbre's noisy attack renders the same
/// every time and stays unit-testable — no `Float.random` nondeterminism.
private struct NoiseSource {
    private var state: UInt64 = 0x9E37_79B9_7F4A_7C15
    /// Next sample in [-1, 1).
    mutating func next() -> Double {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        // Top 53 bits → [0, 1), then mapped to [-1, 1).
        let unit = Double(state >> 11) * (1.0 / 9_007_199_254_740_992.0)
        return unit * 2 - 1
    }
}
