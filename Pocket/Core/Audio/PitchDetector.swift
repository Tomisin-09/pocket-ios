import Foundation

/// Monophonic **pitch detection** for the tuner (ADR 0115). Pure — `[Float]` samples in, an optional
/// fundamental frequency out, no AVFoundation — so the tuner's core is unit-tested against
/// synthesized tones and stays off the audio classes.
///
/// The method is a normalized autocorrelation (McLeod's *Normalized Square Difference Function*),
/// **not** an FFT, because a plucked guitar/bass string is a single strong-fundamental source and its
/// low strings are exactly where FFT bin resolution is worst and time-domain correlation is strongest
/// (ADR 0115 Context — bass low-E1 sits near 41 Hz). The NSDF is bounded to `[-1, 1]`, peaks at `1`
/// for a perfectly periodic signal, and — with the zero-lag lobe skipped and a "first strong peak"
/// pick — is robust to the octave errors a naive autocorrelation makes on harmonic-rich tones.
struct PitchDetector {

    /// Lowest fundamental we search for — a hair under bass low-D (D1 ≈ 36.7 Hz) in a drop tuning.
    var minFrequency: Double = 30
    /// Highest fundamental — comfortably above a fretted high-E string.
    var maxFrequency: Double = 1_200
    /// Minimum signal RMS to attempt detection; below this the buffer is treated as silence and the
    /// tuner holds its last reading rather than chasing room noise.
    var silenceThreshold: Double = 0.01
    /// Minimum NSDF clarity (0…1) of the best peak to trust a result — rejects noise, breath, and the
    /// tail of a fully-decayed note. A clean tone peaks near 1; broadband noise stays well below this.
    var clarityThreshold: Double = 0.8
    /// A candidate peak counts as "the fundamental" if it reaches this fraction of the strongest
    /// peak. Picking the *first* such peak (shortest lag) is what avoids dropping an octave on a tone
    /// whose 2nd harmonic correlates almost as strongly as its fundamental.
    var peakThresholdFactor: Double = 0.9

    /// The detected fundamental in Hz, or `nil` when the buffer is too quiet, too short, or too
    /// noisy/inharmonic to trust.
    func detect(_ samples: [Float], sampleRate: Double) -> Double? {
        guard sampleRate > 0, samples.count > 1 else { return nil }
        guard let signal = conditioned(samples) else { return nil }     // silence-gated + DC-removed

        let maxLag = min(signal.count - 1, Int((sampleRate / minFrequency).rounded(.up)))
        let minLag = max(1, Int((sampleRate / maxFrequency).rounded(.down)))
        guard maxLag > minLag else { return nil }

        let nsdf = computeNSDF(signal, maxLag: maxLag)
        guard let lag = estimateLag(nsdf, minLag: minLag, maxLag: maxLag) else { return nil }

        let frequency = sampleRate / lag
        guard frequency >= minFrequency, frequency <= maxFrequency else { return nil }
        return frequency
    }

    // MARK: - Stages

    /// Silence-gate on RMS, then subtract the DC offset so a constant bias can't skew the
    /// correlation. Returns `nil` (don't bother correlating) when the buffer is below `silenceThreshold`.
    private func conditioned(_ samples: [Float]) -> [Double]? {
        var sum = 0.0
        var sumSquares = 0.0
        for sample in samples {
            let value = Double(sample)
            sum += value
            sumSquares += value * value
        }
        let count = Double(samples.count)
        let rms = (sumSquares / count).squareRoot()
        guard rms >= silenceThreshold else { return nil }
        let mean = sum / count
        return samples.map { Double($0) - mean }
    }

    /// The Normalized Square Difference Function for lags `0...maxLag`:
    /// `nsdf[τ] = 2·Σ x[i]·x[i+τ] / Σ (x[i]² + x[i+τ]²)`, bounded to `[-1, 1]`. `nsdf[0] == 1`.
    private func computeNSDF(_ signal: [Double], maxLag: Int) -> [Double] {
        let count = signal.count
        var nsdf = [Double](repeating: 0, count: maxLag + 1)
        for lag in 0...maxLag {
            var correlation = 0.0
            var normalizer = 0.0
            let upper = count - lag
            var index = 0
            while index < upper {
                let here = signal[index]
                let there = signal[index + lag]
                correlation += here * there
                normalizer += here * here + there * there
                index += 1
            }
            nsdf[lag] = normalizer > 0 ? 2 * correlation / normalizer : 0
        }
        return nsdf
    }

    /// Pick the fundamental's lag from the NSDF. Skips the central zero-lag lobe (which is meaningless
    /// periodicity), collects the maximum of each subsequent positive region, then chooses the *first*
    /// region peak reaching `peakThresholdFactor` of the strongest — the octave-safe choice. Returns a
    /// sub-sample lag via parabolic interpolation, or `nil` if nothing is clear enough.
    private func estimateLag(_ nsdf: [Double], minLag: Int, maxLag: Int) -> Double? {
        var lobeEnd = 1
        while lobeEnd <= maxLag && nsdf[lobeEnd] > 0 { lobeEnd += 1 }
        let searchLow = max(minLag, lobeEnd)
        guard searchLow < maxLag else { return nil }

        let maxima = regionMaxima(nsdf, from: searchLow, to: maxLag)
        guard let strongest = maxima.map(\.value).max(), strongest >= clarityThreshold else { return nil }

        let threshold = peakThresholdFactor * strongest
        guard let chosen = maxima.first(where: { $0.value >= threshold }) else { return nil }
        return parabolicPeakLag(nsdf, around: chosen.lag)
    }

    /// The (lag, value) high point of each contiguous positive region of the NSDF in `low...high`.
    private func regionMaxima(_ nsdf: [Double], from low: Int, to high: Int) -> [(lag: Int, value: Double)] {
        var maxima: [(lag: Int, value: Double)] = []
        var index = low
        while index <= high {
            guard nsdf[index] > 0 else { index += 1; continue }
            var best = index
            while index <= high && nsdf[index] > 0 {
                if nsdf[index] > nsdf[best] { best = index }
                index += 1
            }
            maxima.append((best, nsdf[best]))
        }
        return maxima
    }

    /// Refine an integer peak lag to sub-sample precision by fitting a parabola to the peak and its
    /// two neighbours — worth ~cents of accuracy, especially on the high strings where a whole-sample
    /// lag is coarse. Falls back to the integer lag at the array edges or a degenerate fit.
    private func parabolicPeakLag(_ nsdf: [Double], around lag: Int) -> Double {
        guard lag > 0, lag < nsdf.count - 1 else { return Double(lag) }
        let before = nsdf[lag - 1]
        let peak = nsdf[lag]
        let after = nsdf[lag + 1]
        let denominator = before - 2 * peak + after
        guard denominator != 0 else { return Double(lag) }
        let shift = 0.5 * (before - after) / denominator
        return Double(lag) + shift
    }
}
