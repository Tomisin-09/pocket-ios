import Foundation

/// Pure, UI-free on-device tempo estimation — rung 2 of ADR 0004's fallback chain
/// ("else optionally estimate on-device, flagged as estimated").
///
/// Works on an **onset-strength envelope** (`AudioMath.onsetEnvelope`): a coarse
/// energy-rise curve where drum/note onsets spike. The beat period shows up as the
/// lag at which that curve most strongly repeats, so the estimate is the peak of its
/// autocorrelation. ADR 0004 calls out the classic failure — landing on half- or
/// double-tempo — so each lag's correlation is weighted by a **log-normal prior**
/// centred on a typical tempo: when a genuine beat and its octave both show energy,
/// the one nearer the prior wins, folding most half/double errors back in. The
/// estimate is never ground truth (the ADR is explicit), so the UI presents it as
/// *estimated* and the user confirms or corrects it; speed never depends on it.
///
/// Free of SwiftUI/AVFoundation so the arithmetic is exhaustively unit-tested (the
/// AGENTS.md rule: the logic with no UI coverage is what breaks silently).
enum TempoEstimator {

    /// BPM band the autocorrelation searches. Wider than the musical centre so a fast
    /// or slow song is still found before the prior folds octaves; clamped again to
    /// `TempoMath.minTapBPM...maxTapBPM` on the way out.
    static let searchRange: ClosedRange<Double> = 50...210

    /// Centre of the log-normal tempo prior — most popular music clusters here, so it
    /// resolves the octave ambiguity toward a plausible reading.
    static let preferredBPM = 120.0

    /// Spread of the prior in natural-log space. ~0.6 spans roughly an octave at one
    /// sigma, so a true tempo far from `preferredBPM` is still reachable, but a spurious
    /// double/half that sits ~0.69 (`ln 2`) away is meaningfully discounted.
    static let priorSigma = 0.6

    /// A full on-device tempo reading: the estimated tempo and, when found, the
    /// **phase anchor** for the beat grid — the seconds at which a beat (treated as
    /// "the 1") lands. `downbeatSeconds` is `nil` when the phase can't be placed.
    struct Estimate: Equatable, Sendable {
        let bpm: Double
        let downbeatSeconds: TimeInterval?
    }

    /// Estimate tempo **and** downbeat phase in one pass over the same onset envelope.
    /// Returns `nil` when there's no confident tempo (so there's nothing to phase-align).
    static func estimate(onsets: [Double], framesPerSecond: Double,
                         preferredBPM: Double = preferredBPM) -> Estimate? {
        guard let bpm = estimateBPM(onsets: onsets, framesPerSecond: framesPerSecond,
                                    preferredBPM: preferredBPM) else { return nil }
        let downbeat = estimateDownbeat(onsets: onsets, framesPerSecond: framesPerSecond, bpm: bpm)
        return Estimate(bpm: bpm, downbeatSeconds: downbeat)
    }

    /// Minimum normalised autocorrelation at the chosen lag for the estimate to be
    /// trusted. Flat or rubato/ambient material (ADR 0004's hard case) has no sharp
    /// repeat, so its peak stays low and we return `nil` — "no confident estimate" —
    /// rather than inventing a tempo.
    static let minConfidence = 0.1

    /// Estimate a tempo (BPM) from an onset-strength envelope sampled at
    /// `framesPerSecond`. Returns `nil` when the envelope is too short, silent, or has
    /// no clear periodicity (confidence below `minConfidence`). The result is the
    /// autocorrelation peak — sub-frame-refined by parabolic interpolation so the BPM
    /// isn't quantised to the frame grid — weighted by the tempo prior, then clamped to
    /// the tappable range so a degenerate lag can't yield an absurd value.
    static func estimateBPM(onsets: [Double], framesPerSecond: Double,
                            preferredBPM: Double = preferredBPM) -> Double? {
        guard framesPerSecond > 0, onsets.count > 8 else { return nil }

        // Mean-remove so a loud sustained bed doesn't swamp the rhythmic rises.
        let mean = onsets.reduce(0, +) / Double(onsets.count)
        let signal = onsets.map { $0 - mean }
        let energy = signal.reduce(0) { $0 + $1 * $1 }
        guard energy > 0 else { return nil }

        // Lag bounds (in frames) for the search band. Higher BPM ⇒ shorter lag.
        let minLag = max(1, Int((60 * framesPerSecond / searchRange.upperBound).rounded()))
        let maxLag = min(signal.count - 1, Int((60 * framesPerSecond / searchRange.lowerBound).rounded()))
        guard minLag < maxLag else { return nil }

        func autocorr(_ lag: Int) -> Double {
            var sum = 0.0
            for index in lag..<signal.count { sum += signal[index] * signal[index - lag] }
            return sum / energy
        }
        func bpm(forLag lag: Double) -> Double { 60 * framesPerSecond / lag }
        func prior(_ value: Double) -> Double {
            let deviation = log(value / preferredBPM) / priorSigma
            return exp(-0.5 * deviation * deviation)
        }

        var bestLag = minLag
        var bestScore = -Double.greatestFiniteMagnitude
        var bestRaw = 0.0
        for lag in minLag...maxLag {
            let raw = autocorr(lag)
            guard raw > 0 else { continue }
            let score = raw * prior(bpm(forLag: Double(lag)))
            if score > bestScore {
                bestScore = score
                bestLag = lag
                bestRaw = raw
            }
        }
        guard bestRaw >= minConfidence else { return nil }

        // Parabolic interpolation around the integer peak for sub-frame precision.
        let refinedLag = interpolatedPeak(lag: bestLag, autocorr: autocorr,
                                          lowerBound: minLag, upperBound: maxLag)
        return bpm(forLag: refinedLag).clamped(to: TempoMath.minTapBPM...TempoMath.maxTapBPM)
    }

    /// Place the beat-grid **phase anchor** ("the 1") from the onset envelope, given an
    /// already-estimated `bpm`. BPM fixes the beat *interval*; this finds the *offset* —
    /// a comb-filter that slides a pulse train at the beat period across the envelope and
    /// keeps the phase whose beats collect the most onset energy, i.e. the offset that
    /// lands beats on real hits (usually kicks). Returns the seconds of the first such
    /// beat, or `nil` for a degenerate period / silent envelope.
    ///
    /// This pins the *beat* phase reliably, but not which beat is bar-1 (1 vs 2/3/4) —
    /// that needs bar-level structure we don't analyse, so the anchor can sit a beat or
    /// two off the true downbeat. The grid still lines up with every beat; the user nudges
    /// which one is the 1. Returned as a beat the caller commits to `Song.downbeatSeconds`.
    static func estimateDownbeat(onsets: [Double], framesPerSecond: Double, bpm: Double) -> TimeInterval? {
        guard framesPerSecond > 0, bpm > 0, onsets.count > 8 else { return nil }
        let period = 60 * framesPerSecond / bpm
        let periodInt = Int(period.rounded())
        guard periodInt >= 1, periodInt < onsets.count else { return nil }

        var bestOffset = 0
        var bestScore = -1.0
        for offset in 0..<periodInt {
            var score = 0.0
            var beat = Double(offset)
            while beat < Double(onsets.count) {
                let index = Int(beat.rounded())
                if index < onsets.count { score += onsets[index] }
                beat += period
            }
            if score > bestScore {
                bestScore = score
                bestOffset = offset
            }
        }
        guard bestScore > 0 else { return nil }
        return Double(bestOffset) / framesPerSecond
    }

    /// Sub-frame peak position from the three autocorrelation samples around `lag`.
    /// A symmetric parabola through `(lag±1)` locates the true maximum between frames;
    /// at the search edges (no neighbour) we keep the integer lag.
    private static func interpolatedPeak(lag: Int, autocorr: (Int) -> Double,
                                         lowerBound: Int, upperBound: Int) -> Double {
        guard lag > lowerBound, lag < upperBound else { return Double(lag) }
        let left = autocorr(lag - 1)
        let mid = autocorr(lag)
        let right = autocorr(lag + 1)
        let denominator = left - 2 * mid + right
        guard denominator != 0 else { return Double(lag) }
        let delta = 0.5 * (left - right) / denominator
        // A well-formed peak shifts by < 1 frame; ignore a degenerate fit.
        guard abs(delta) < 1 else { return Double(lag) }
        return Double(lag) + delta
    }
}
