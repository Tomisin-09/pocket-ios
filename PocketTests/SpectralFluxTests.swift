import XCTest
@testable import Pocket

/// The spectral-flux onset envelope (B1 of the beat map), driven with synthesised audio so the
/// FFT, the semitone bands and the frame timing are checked without decoding a file. The tempo
/// assertions run the envelope through the unchanged `TempoEstimator`, which is the path
/// *Estimate from audio* takes.
final class SpectralFluxTests: XCTestCase {

    private let sampleRate = 44_100.0
    private let framesPerSecond = 100.0

    // MARK: Synthesised material

    /// A sine that changes note on every beat at an **even level**, with its phase carried across
    /// each change so the change itself makes no click. Nothing in it gets louder.
    private func evenMelody(bpm: Double, seconds: Double, amplitude: Float = 0.5) -> [Float] {
        let notes = [261.63, 329.63, 392.0, 523.25, 440.0, 349.23, 293.66, 246.94]
        let beat = 60 / bpm
        var phase = 0.0
        return (0..<Int(seconds * sampleRate)).map { index in
            let note = notes[Int(Double(index) / sampleRate / beat) % notes.count]
            phase += 2 * .pi * note / sampleRate
            return amplitude * Float(sin(phase))
        }
    }

    /// Plucked notes (six harmonics, decaying) on every beat from 0.5 s, over a held two-note chord
    /// that never changes. Returns the audio and the time each note was struck. Each distinct note
    /// is rendered once and copied in, which keeps a Debug-build test run fast.
    private func plucksOverAHeldChord(bpm: Double, seconds: Double, pluck: Double = 0.3,
                                      chord: Float = 0.15) -> (samples: [Float], struck: [Double]) {
        let notes = [110, 146.83, 164.81, 196, 220, 164.81, 146.83, 123.47]
        let count = Int(seconds * sampleRate)
        let length = Int(60 / bpm * sampleRate)
        var rendered: [Double: [Float]] = [:]
        for note in notes where rendered[note] == nil {
            var rendering = [Float](repeating: 0, count: length)
            for offset in 0..<length {
                let time = Double(offset) / sampleRate
                var tone = 0.0
                for harmonic in 1...6 { tone += sin(2 * .pi * note * Double(harmonic) * time) / Double(harmonic) }
                rendering[offset] = Float(pluck * tone * exp(-3 * time))
            }
            rendered[note] = rendering
        }
        var samples = [Float](repeating: 0, count: count)
        for index in 0..<count {
            let time = Double(index) / sampleRate
            samples[index] = chord * Float(sin(2 * .pi * 82.41 * time) + 0.5 * sin(2 * .pi * 123.47 * time))
        }
        var struck: [Double] = []
        var onset = 0.5
        while onset < seconds - 0.1 {
            let note = rendered[notes[struck.count % notes.count]] ?? []
            let first = Int(onset * sampleRate)
            for offset in note.indices where first + offset < count { samples[first + offset] += note[offset] }
            struck.append(onset)
            onset += 60 / bpm
        }
        return (samples, struck)
    }

    /// A kick on every beat and a hi-hat on every off-beat. The hat's noise is seeded, so the
    /// test reads the same every run.
    private func drums(bpm: Double, seconds: Double) -> [Float] {
        let count = Int(seconds * sampleRate)
        let beat = 60 / bpm
        var samples = [Float](repeating: 0, count: count)
        var noise = SeededNoise(seed: 7)
        var onset = 0.0
        while onset < seconds {
            let kick = Int(onset * sampleRate)
            for offset in 0..<Int(0.15 * sampleRate) where kick + offset < count {
                let time = Double(offset) / sampleRate
                let sweep = sin(2 * .pi * (60 + 80 * exp(-30 * time)) * time)
                samples[kick + offset] += Float(0.8 * sweep * exp(-20 * time))
            }
            let hat = Int((onset + beat / 2) * sampleRate)
            for offset in 0..<Int(0.03 * sampleRate) where hat + offset < count {
                samples[hat + offset] += 0.2 * noise.next() * Float(exp(-100 * Double(offset) / sampleRate))
            }
            onset += beat
        }
        return samples
    }

    private func sine(hertz: Double, seconds: Double, amplitude: Float = 0.5) -> [Float] {
        (0..<Int(seconds * sampleRate)).map { amplitude * Float(sin(2 * .pi * hertz * Double($0) / sampleRate)) }
    }

    private func flux(_ samples: [Float]) -> [Double] {
        AudioMath.spectralFlux(samples, sampleRate: sampleRate, framesPerSecond: framesPerSecond)
    }

    // MARK: Hearing new notes

    /// The reason for B1. A melody at an even level has nothing for a loudness envelope to hear
    /// (its 10 ms loudness stays within 10%), and spectral flux still finds its tempo.
    func testAMelodyAtAnEvenLevelGivesItsTempo() throws {
        let melody = evenMelody(bpm: 100, seconds: 20)
        let loudness = AudioMath.bucketRMS(melody, to: 2000)
        let quietest = try XCTUnwrap(loudness.min())
        let loudest = try XCTUnwrap(loudness.max())
        XCTAssertGreaterThan(quietest / loudest, 0.9, "the melody must not get louder anywhere, or this proves nothing")

        let bpm = try XCTUnwrap(TempoEstimator.estimateBPM(onsets: flux(melody), framesPerSecond: framesPerSecond))
        XCTAssertEqual(bpm, 100, accuracy: 2)
    }

    /// The same melody played quietly under a hiss: compression makes a quiet note count, so the
    /// tempo is still found.
    func testAQuietMelodyUnderHissGivesItsTempo() throws {
        var noise = SeededNoise(seed: 3)
        let melody = evenMelody(bpm: 100, seconds: 20, amplitude: 0.05).map { $0 + 0.003 * noise.next() }
        let bpm = try XCTUnwrap(TempoEstimator.estimateBPM(onsets: flux(melody), framesPerSecond: framesPerSecond))
        XCTAssertEqual(bpm, 100, accuracy: 2)
    }

    func testPluckedNotesOverAHeldChordGiveTheirTempo() throws {
        let plucks = plucksOverAHeldChord(bpm: 72, seconds: 15)
        let bpm = try XCTUnwrap(TempoEstimator.estimateBPM(onsets: flux(plucks.samples),
                                                            framesPerSecond: framesPerSecond))
        XCTAssertEqual(bpm, 72, accuracy: 2)
    }

    /// Why the bands are a semitone wide. A quiet line (plucks at a quarter of the chord's level)
    /// over a loud held chord: in its own band each note rises from nothing, so it counts. Summed
    /// into one band it is a small change to a big total, and the held chord's own ripple wins: a
    /// single band read this as 107 BPM, and the old loudness envelope as 118.
    func testAQuietLineOverALoudHeldChordGivesItsTempo() throws {
        let plucks = plucksOverAHeldChord(bpm: 72, seconds: 15, pluck: 0.1, chord: 0.4)
        let bpm = try XCTUnwrap(TempoEstimator.estimateBPM(onsets: flux(plucks.samples),
                                                            framesPerSecond: framesPerSecond))
        XCTAssertEqual(bpm, 72, accuracy: 2)
    }

    /// Where each onset lands, which the beat finder (B3) will build on: the strongest frame near
    /// each pluck is within 20 ms of where it was struck.
    func testEachOnsetLandsWhereTheNoteWasStruck() {
        let plucks = plucksOverAHeldChord(bpm: 95, seconds: 10)
        let envelope = flux(plucks.samples)
        for struck in plucks.struck {
            let expected = Int((struck * framesPerSecond).rounded())
            let window = max(1, expected - 8)...min(envelope.count - 1, expected + 8)
            let peak = window.max { envelope[$0] < envelope[$1] } ?? expected
            XCTAssertEqual(Double(peak) / framesPerSecond, struck, accuracy: 0.02, "the pluck at \(struck) s")
        }
    }

    func testDrumsStillGiveTheirTempo() throws {
        let bpm = try XCTUnwrap(TempoEstimator.estimateBPM(onsets: flux(drums(bpm: 128, seconds: 20)),
                                                            framesPerSecond: framesPerSecond))
        XCTAssertEqual(bpm, 128, accuracy: 2)
    }

    // MARK: Hearing nothing where there is nothing

    /// A held tone has no onsets after it starts, including at the very end of the file, where a
    /// window running past the last sample would read the cut as a click.
    func testASteadyToneHasNoOnsetsAfterItStarts() {
        let envelope = flux(sine(hertz: 440, seconds: 5))
        XCTAssertLessThan(envelope.dropFirst(10).max() ?? 0, 0.05)
    }

    func testSilenceHasNoOnsets() {
        let envelope = flux([Float](repeating: 0, count: 44_100))
        XCTAssertFalse(envelope.isEmpty)
        XCTAssertEqual(envelope.max(), 0)
    }

    /// Hiss on its own must not compress into a tempo: it has no repeat, so the estimate stays nil.
    func testNoiseAloneGivesNoTempo() {
        var noise = SeededNoise(seed: 11)
        let hiss = (0..<Int(20 * sampleRate)).map { _ in 0.01 * noise.next() }
        XCTAssertNil(TempoEstimator.estimateBPM(onsets: flux(hiss), framesPerSecond: framesPerSecond))
    }

    // MARK: Frames

    /// Frame `i` sits at `i / framesPerSecond` seconds at any sample rate, including one where the
    /// hop isn't a whole number of samples (22.05 kHz: 220.5). A tone starting at 0.5 s puts its
    /// onset at frame 50.
    func testFramesKeepTimeAtAnySampleRate() {
        for rate in [48_000.0, 22_050.0] {
            let silence = [Float](repeating: 0, count: Int(rate / 2))
            let tone = (0..<Int(rate / 2)).map { Float(0.5 * sin(2 * .pi * 440 * Double($0) / rate)) }
            let envelope = AudioMath.spectralFlux(silence + tone, sampleRate: rate, framesPerSecond: framesPerSecond)
            let peak = envelope.indices.max { envelope[$0] < envelope[$1] } ?? 0
            XCTAssertEqual(Double(peak), 50, accuracy: 2, "at \(rate) Hz")
        }
    }

    /// The frames stop where the window would run past the end: at 48 kHz the window is 2048
    /// samples, so one second gives frames centred up to sample 46,976, which is 98 of them.
    func testFramesStopBeforeTheWindowRunsOffTheEnd() {
        let envelope = AudioMath.spectralFlux([Float](repeating: 0.1, count: 48_000),
                                              sampleRate: 48_000, framesPerSecond: framesPerSecond)
        XCTAssertEqual(envelope.count, 98)
        XCTAssertEqual(envelope.first, 0)
    }

    func testDegenerateInputGivesNoEnvelope() {
        XCTAssertTrue(flux([]).isEmpty)
        XCTAssertTrue(flux([Float](repeating: 0.1, count: 500)).isEmpty, "shorter than half a window")
        XCTAssertTrue(AudioMath.spectralFlux([0.1, 0.2], sampleRate: 0, framesPerSecond: 100).isEmpty)
        XCTAssertTrue(AudioMath.spectralFlux([0.1, 0.2], sampleRate: 44_100, framesPerSecond: 0).isEmpty)
    }

    func testWindowIsAbout46MillisecondsAtAnySampleRate() {
        XCTAssertEqual(AudioMath.fluxLog2FFTSize(sampleRate: 44_100), 11)
        XCTAssertEqual(AudioMath.fluxLog2FFTSize(sampleRate: 48_000), 11)
        XCTAssertEqual(AudioMath.fluxLog2FFTSize(sampleRate: 96_000), 12)
        XCTAssertEqual(AudioMath.fluxLog2FFTSize(sampleRate: 22_050), 10)
        XCTAssertEqual(AudioMath.fluxLog2FFTSize(sampleRate: 1_000_000), 13, "clamped")
    }

    // MARK: Bands

    /// The bands tile 30 Hz to 16 kHz with no gaps or overlaps, and above the range where a bin is
    /// wider than a semitone, no band is wider than one.
    func testBandsTileTheRangeASemitoneWide() throws {
        let size = 2048
        let binHz = sampleRate / Double(size)
        let bands = AudioMath.fluxBands(fftSize: size, sampleRate: sampleRate)
        let first = try XCTUnwrap(bands.first)
        let last = try XCTUnwrap(bands.last)
        XCTAssertEqual(first.lowerBound, Int((AudioMath.fluxLowestHz / binHz).rounded(.up)))
        XCTAssertEqual(last.upperBound, Int((AudioMath.fluxHighestHz / binHz).rounded(.down)) + 1)
        for (earlier, later) in zip(bands, bands.dropFirst()) {
            XCTAssertEqual(earlier.upperBound, later.lowerBound, "bands are contiguous")
        }
        let semitone = pow(2, 1 / 12.0)
        for band in bands where Double(band.lowerBound) * binHz > 500 && band.count > 1 {
            let span = Double(band.upperBound - 1) / Double(band.lowerBound)
            XCTAssertLessThanOrEqual(span, semitone + 1e-9, "band \(band)")
        }
    }

    /// Two notes a semitone apart (A4 and B♭4) land in different bands, which is what lets a melody
    /// moving by step register as a change.
    func testNeighbouringNotesLandInDifferentBands() throws {
        let size = 2048
        let binHz = sampleRate / Double(size)
        let bands = AudioMath.fluxBands(fftSize: size, sampleRate: sampleRate)
        func band(of hertz: Double) throws -> Int {
            let bin = Int((hertz / binHz).rounded())
            return try XCTUnwrap(bands.firstIndex { $0.contains(bin) })
        }
        XCTAssertNotEqual(try band(of: 440), try band(of: 466.16))
    }

    func testBandsAtANarrowSampleRateStopAtNyquist() throws {
        let bands = AudioMath.fluxBands(fftSize: 512, sampleRate: 8000)
        XCTAssertEqual(try XCTUnwrap(bands.last).upperBound, 256, "every bin up to Nyquist")
        XCTAssertTrue(AudioMath.fluxBands(fftSize: 2, sampleRate: 8000).isEmpty)
    }
}

/// A small seeded noise source (SplitMix64), so noise in a test reads the same on every run and
/// every machine. Values are uniform in -1...1.
private struct SeededNoise {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> Float {
        state &+= 0x9E37_79B9_7F4A_7C15
        var mixed = state
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        mixed ^= mixed >> 31
        return Float(Double(mixed >> 11) / Double(1 << 53)) * 2 - 1
    }
}
