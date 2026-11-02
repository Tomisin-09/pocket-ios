import Accelerate
import Foundation

/// The onset envelope the tempo estimate listens to (ADR 0004, rung 2): **spectral flux**, the
/// first slice of the beat map (B1, `docs/backlog.md`).
///
/// The envelope it replaces measured how much *louder* each 10 ms frame got. That hears a kick or
/// a strum, but a melody played at an even level has no rises in loudness, so a song without drums
/// gave no tempo, or a wrong one: on a synthetic melody changing note every beat at 100 BPM, the
/// loudness envelope's ripple autocorrelated to 154 BPM. Spectral flux measures how much energy
/// *arrives in each frequency band*, so a new note registers even when nothing gets louder,
/// because its energy lands in bands that were quiet a frame ago.
///
/// Pure (Accelerate only, no AVFoundation), so it stays unit-testable per AGENTS.md.
extension AudioMath {

    /// How strongly band levels are log-compressed: each band reads `log(1 + γ·level)`. Compression
    /// makes the flux respond to *relative* change, so a new note in a quiet verse counts nearly as
    /// much as one in a loud chorus. 100 was chosen over 1000 because a steady tone then reads as
    /// almost no flux (0.009 against 0.08), and an onset is placed about 6 ms early rather than
    /// 10 ms; background noise alone still stays below `TempoEstimator.minConfidence` either way.
    static let fluxCompression: Float = 100

    /// The band range the flux sums over. Below 30 Hz is rumble. Above 16 kHz carries little that
    /// starts a note, and a lossy file has often cut it away.
    static let fluxLowestHz = 30.0
    static let fluxHighestHz = 16_000.0

    /// The analysis window, about 46 ms: 2048 samples at 44.1 or 48 kHz. Long enough that the
    /// harmonics of neighbouring guitar notes land in different bins; much longer and an onset
    /// smears across several frames.
    static let fluxWindowSeconds = 0.046

    /// The **spectral-flux onset envelope** of `samples`, one value per frame at `framesPerSecond`.
    ///
    /// Frame `i` is a Hann-windowed FFT centred on sample `i · sampleRate / framesPerSecond`, so the
    /// rate is exact even when the hop isn't a whole number of samples. Each frame's magnitudes are
    /// summed into the bands of `fluxBands` and log-compressed; the frame's value is the sum of each
    /// band's **rise** from the previous frame (falls are ignored, since a note stopping is not an
    /// onset). The first frame is 0 (it has no predecessor).
    ///
    /// The frames stop where the window would run past the last sample. A file that ends on a hard
    /// cut otherwise reads as a huge onset at the very end: the zero padding makes the cut a click,
    /// and a click spreads energy into every band.
    static func spectralFlux(_ samples: [Float], sampleRate: Double,
                             framesPerSecond: Double) -> [Double] {
        guard sampleRate > 0, framesPerSecond > 0 else { return [] }
        let log2Size = fluxLog2FFTSize(sampleRate: sampleRate)
        let size = 1 << log2Size
        let half = size / 2
        let hop = sampleRate / framesPerSecond
        let bands = fluxBands(fftSize: size, sampleRate: sampleRate)
        guard samples.count >= half, !bands.isEmpty,
              let setup = vDSP_create_fftsetup(vDSP_Length(log2Size), FFTRadix(kFFTRadix2)) else { return [] }
        defer { vDSP_destroy_fftsetup(setup) }

        let frameCount = Int(Double(samples.count - half) / hop) + 1
        var spectrum = FluxSpectrum(size: size, log2Size: log2Size, setup: setup)
        var previous = [Float](repeating: 0, count: bands.count)
        var flux = [Double](repeating: 0, count: frameCount)
        for index in 0..<frameCount {
            let centre = Int((Double(index) * hop).rounded())
            let levels = spectrum.bandLevels(samples, centre: centre, bands: bands)
            if index > 0 {
                var rise = 0.0
                for band in 0..<levels.count { rise += Double(max(0, levels[band] - previous[band])) }
                flux[index] = rise
            }
            previous = levels
        }
        return flux
    }

    /// `log2` of the FFT size for a sample rate: the power of two nearest `fluxWindowSeconds`,
    /// kept between 512 and 8192 samples so an odd sample rate can't produce an absurd window.
    static func fluxLog2FFTSize(sampleRate: Double) -> Int {
        guard sampleRate > 0 else { return 11 }
        return Int(log2(sampleRate * fluxWindowSeconds).rounded()).clamped(to: 9...13)
    }

    /// The FFT bins summed into each flux band, as contiguous ranges in rising order.
    ///
    /// Bands are a **semitone** wide, so each note is compressed on its own. A quiet note arriving
    /// over a loud held chord rises from nothing in its own band and counts; in one wide band it is
    /// a small change to a big total. Measured on plucks at a quarter of a held chord's level, at
    /// 72 BPM: semitone bands found 72, a single band 107. Low down, where one bin is wider than a
    /// semitone, each bin is its own band. Bins outside `fluxLowestHz...fluxHighestHz` (and DC)
    /// belong to no band.
    static func fluxBands(fftSize: Int, sampleRate: Double) -> [Range<Int>] {
        guard fftSize >= 4, sampleRate > 0 else { return [] }
        let binHz = sampleRate / Double(fftSize)
        let highest = min(sampleRate / 2, fluxHighestHz)
        var bands: [Range<Int>] = []
        var bandStart = -1
        var bandSemitone = Int.min
        var lastBin = -1
        for bin in 1..<(fftSize / 2) {
            let hertz = Double(bin) * binHz
            guard hertz >= fluxLowestHz else { continue }
            guard hertz <= highest else { break }
            let semitone = Int((12 * log2(hertz / fluxLowestHz)).rounded(.down))
            if semitone != bandSemitone {
                if bandStart >= 0 { bands.append(bandStart..<bin) }
                bandStart = bin
                bandSemitone = semitone
            }
            lastBin = bin
        }
        if bandStart >= 0 { bands.append(bandStart..<(lastBin + 1)) }
        return bands
    }
}

/// One frame's worth of FFT working memory for `AudioMath.spectralFlux`, allocated once per song
/// rather than once per frame (a four-minute song is about 24,000 frames).
private struct FluxSpectrum {
    let size: Int
    let log2Size: Int
    let setup: FFTSetup
    private var window: [Float]
    private var frame: [Float]
    private var real: [Float]
    private var imaginary: [Float]
    private var magnitudes: [Float]

    init(size: Int, log2Size: Int, setup: FFTSetup) {
        self.size = size
        self.log2Size = log2Size
        self.setup = setup
        window = [Float](repeating: 0, count: size)
        vDSP_hann_window(&window, vDSP_Length(size), Int32(vDSP_HANN_NORM))
        frame = [Float](repeating: 0, count: size)
        real = [Float](repeating: 0, count: size / 2)
        imaginary = [Float](repeating: 0, count: size / 2)
        magnitudes = [Float](repeating: 0, count: size / 2)
    }

    /// The log-compressed level of each band for the window centred on sample `centre`. Samples
    /// before the start of the song read as silence.
    mutating func bandLevels(_ samples: [Float], centre: Int, bands: [Range<Int>]) -> [Float] {
        fillWindowedFrame(samples, start: centre - size / 2)
        computeMagnitudes()
        // `zrip` returns twice the DFT, and a Hann window halves a sine's peak, so dividing by the
        // size puts a full-scale sine's peak bin near 0.5 whatever the window length.
        let scale = 1 / Float(size)
        return magnitudes.withUnsafeBufferPointer { mags in
            guard let base = mags.baseAddress else { return [] }
            return bands.map { band in
                var sum: Float = 0
                vDSP_sve(base + band.lowerBound, 1, &sum, vDSP_Length(band.count))
                return log1pf(AudioMath.fluxCompression * sum * scale)
            }
        }
    }

    private mutating func fillWindowedFrame(_ samples: [Float], start: Int) {
        if start >= 0, start + size <= samples.count {
            samples.withUnsafeBufferPointer { source in
                guard let base = source.baseAddress else { return }
                vDSP_vmul(base + start, 1, window, 1, &frame, 1, vDSP_Length(size))
            }
            return
        }
        for offset in 0..<size {
            let sample = start + offset
            frame[offset] = sample >= 0 && sample < samples.count ? samples[sample] * window[offset] : 0
        }
    }

    private mutating func computeMagnitudes() {
        let half = size / 2
        real.withUnsafeMutableBufferPointer { realBuffer in
            imaginary.withUnsafeMutableBufferPointer { imaginaryBuffer in
                guard let realBase = realBuffer.baseAddress,
                      let imaginaryBase = imaginaryBuffer.baseAddress else { return }
                var split = DSPSplitComplex(realp: realBase, imagp: imaginaryBase)
                frame.withUnsafeBufferPointer { frameBuffer in
                    frameBuffer.baseAddress?.withMemoryRebound(to: DSPComplex.self, capacity: half) { packed in
                        vDSP_ctoz(packed, 2, &split, 1, vDSP_Length(half))
                    }
                }
                vDSP_fft_zrip(setup, &split, 1, vDSP_Length(log2Size), FFTDirection(FFT_FORWARD))
                vDSP_zvabs(&split, 1, &magnitudes, 1, vDSP_Length(half))
            }
        }
    }
}
