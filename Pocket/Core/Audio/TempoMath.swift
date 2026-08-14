import Foundation

/// Pure, UI-free tempo + speed-slider math.
///
/// Kept deliberately free of SwiftUI/AVFoundation so it can be exhaustively
/// unit-tested (the Docket lesson: the logic with no UI coverage is exactly the
/// logic that breaks silently). Everything here is a static, deterministic
/// function of its inputs.
enum TempoMath {

    /// Playback speed bounds (× of original tempo). **One axis, one ceiling** (ADR 0124): the
    /// waveform slider, the per-loop automator ramp and the loop / song-play-along percent sliders
    /// all quote these, so the slow-downer can never outrun the ramp it drives. The ceiling came
    /// down from 2.0× — above ~1.5× the time-stretch smears the transients practice is listening
    /// for, so the extra range was resolution spent on speeds nobody could use.
    static let minSpeed = 0.25
    static let maxSpeed = 1.5
    static let defaultSpeed = 1.0

    /// Fraction of the slider track occupied by the slow segment (0.25×–1.0×).
    /// Asymmetric on purpose: slow practice is the primary use case, so 1.0×
    /// sits slightly left of centre and the slow range gets more precision.
    static let splitPosition = 0.54

    /// Effective BPM at a given speed: `round(songBPM × speed)`.
    /// Rounds half away from zero, so 85 BPM × 0.50× = 42.5 → 43 (per brief).
    static func effectiveBPM(songBPM: Int, speed: Double) -> Int {
        Int((Double(songBPM) * speed).rounded())
    }

    /// Map a slider position in `0...1` to a playback speed in `0.25...2.0`,
    /// using the two-segment asymmetric scale.
    static func speed(forPosition position: Double) -> Double {
        let pos = position.clamped(to: 0...1)
        if pos <= splitPosition {
            let frac = pos / splitPosition
            return minSpeed + frac * (defaultSpeed - minSpeed)
        } else {
            let frac = (pos - splitPosition) / (1 - splitPosition)
            return defaultSpeed + frac * (maxSpeed - defaultSpeed)
        }
    }

    /// Inverse of `speed(forPosition:)` — map a speed back to a slider position.
    static func position(forSpeed speed: Double) -> Double {
        let spd = speed.clamped(to: minSpeed...maxSpeed)
        if spd <= defaultSpeed {
            return splitPosition * (spd - minSpeed) / (defaultSpeed - minSpeed)
        } else {
            return splitPosition + (1 - splitPosition) * (spd - defaultSpeed) / (maxSpeed - defaultSpeed)
        }
    }

    /// The same axis as **integer percent of original** — the form the loop-run and song-play-along
    /// tempo fields work in (ADR 0082's "loop tempos are always %"). Lives here, not on either
    /// screen: it's a bound, not view state, and a copy on a SwiftUI `View` is main-actor isolated,
    /// so nothing off the main actor (a test, a pure helper) can read it.
    static let percentRange = Int(minSpeed * 100)...Int(maxSpeed * 100)

    /// Clamp a speed onto the supported axis. The **read-side** guard for the ceiling move (ADR
    /// 0124): nothing authored under the old 2.0× ceiling needed rewriting, but every stored speed
    /// (a loop's command tempo, a song's resume speed, an automator's start/target) passes through
    /// here so a legacy value can't hand the engine a rate the UI can no longer show.
    static func clamped(speed: Double) -> Double { speed.clamped(to: minSpeed...maxSpeed) }

    /// The outcome of typing a speed into the custom-entry field (ADR 0124). Pure, so the
    /// rejection message is decided by testable rules rather than by the view.
    enum SpeedEntry: Equatable {
        case valid(Double)
        case notANumber
        case outOfRange
    }

    /// Parse a typed speed — a bare multiplier, with an optional `×`/`x` suffix and either decimal
    /// separator. Out-of-range is its **own** answer, not a silent clamp: typing 2× under a 1.5×
    /// ceiling is a mistake worth naming, and quietly accepting 1.5 would look like the field
    /// ignored the keystrokes.
    static func parse(speedEntry text: String) -> SpeedEntry {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
            .replacingOccurrences(of: "×", with: "")
            .replacingOccurrences(of: "x", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)
        guard let value = Double(trimmed), value.isFinite else { return .notANumber }
        guard (minSpeed...maxSpeed).contains(value) else { return .outOfRange }
        return .valid(value)
    }

    /// Musical bounds for a tapped tempo. A double-tap or a long pause would
    /// otherwise yield an absurd BPM; clamping keeps the result usable (ADR 0024).
    static let minTapBPM = 30.0
    static let maxTapBPM = 300.0

    /// How many of the most recent inter-tap **gaps** the reading is taken from (ADR 0166).
    /// Twelve gaps is thirteen taps — roughly three bars of 4/4: long enough to average out
    /// a hand's jitter, short enough to follow music whose pulse actually moves. Averaging
    /// *every* gap instead reads the mean of the whole tapping session, which on
    /// hand-played material is a number that fits neither end of it, and grows steadily
    /// less responsive as taps accumulate (the 40th tap moves it by a fortieth).
    ///
    /// Widened from 8 after device testing (ADR 0166 §Revision): a mistimed tap is a
    /// **paired** error — tapping early shortens one gap and lengthens the next by the same
    /// amount — so the two cancel in the mean *provided both sit inside the window*. At
    /// eight, a fumble near the edge was split, one half rolled out, and the surviving half
    /// visibly moved the reading.
    static let tapWindow = 12

    /// How far a gap may sit from the window's median and still count, as a fraction of
    /// that median (ADR 0166). The window makes each gap worth ~1/12 rather than ~1/40, so
    /// a single fumbled tap does *more* damage than it used to — rejection is the window's
    /// counterpart, not a separate refinement.
    ///
    /// Tightened from 0.3 after device testing. At 0.3, tapping 0.5 s gaps, anything from
    /// 0.35 to 0.65 counted — a tap 30% off the beat sailed through, which is what leaked
    /// into the reading. 0.15 still leaves roughly seven times the headroom genuine movement
    /// needs (89 → 93 BPM across one window puts the extremes ~2.2% from the median) and
    /// comfortably clears ordinary hand jitter, while rejecting both gross errors — a
    /// double-tap ≈ 0.5× the median, a missed beat ≈ 2× — and the moderate mistiming that
    /// the wider band let through.
    static let tapOutlierTolerance = 0.15

    /// Fewest gaps for which a median means anything. Below this every gap is kept — with
    /// two or three taps there is no majority to be an outlier *from*, and rejecting
    /// against a two-sample median would just discard the higher one.
    static let minGapsForOutlierRejection = 4

    /// BPM inferred from a series of tap timestamps in **song-time seconds**, ascending.
    ///
    /// Reads the **last `window` gaps only** (ADR 0166), discarding any non-positive gap
    /// first — a tap whose loop wrapped playback back to an earlier song position straddles
    /// the boundary and can't measure tempo (ADR 0024). Those gaps then have their outliers
    /// dropped before the mean is taken, so one fumbled tap doesn't drag the reading.
    /// Returns `nil` with fewer than two usable taps; clamps to `minTapBPM...maxTapBPM`.
    ///
    /// Capturing song-time (not wall-clock) is what makes tapping inside a loop or at a
    /// reduced speed read the song's true tempo automatically. Pass `window: 0` for the
    /// unwindowed mean over every gap — which is more accurate on genuinely steady material,
    /// and is the behaviour this replaced.
    static func bpm(fromTapTimes times: [TimeInterval], window: Int = tapWindow) -> Double? {
        guard times.count >= 2 else { return nil }
        var intervals: [TimeInterval] = []
        for index in 1..<times.count {
            let gap = times[index] - times[index - 1]
            if gap > 0 { intervals.append(gap) }
        }
        guard !intervals.isEmpty else { return nil }
        let recent = window > 0 ? Array(intervals.suffix(window)) : intervals
        let kept = rejectingOutliers(recent)
        let mean = kept.reduce(0, +) / Double(kept.count)
        guard mean > 0 else { return nil }
        return (60.0 / mean).clamped(to: minTapBPM...maxTapBPM)
    }

    /// `gaps` with anything further than `tapOutlierTolerance` from their median removed.
    /// The median is `AudioMath.percentile(_:0.5)` — the same robust reference the onset
    /// envelope normalises against — so at least half the gaps always survive by
    /// construction and the caller never divides by an empty count. Below
    /// `minGapsForOutlierRejection` the input is returned untouched.
    private static func rejectingOutliers(_ gaps: [TimeInterval]) -> [TimeInterval] {
        guard gaps.count >= minGapsForOutlierRejection else { return gaps }
        let median = AudioMath.percentile(gaps, 0.5)
        guard median > 0 else { return gaps }
        let kept = gaps.filter { abs($0 - median) / median <= tapOutlierTolerance }
        return kept.isEmpty ? gaps : kept
    }

    /// Number of discrete steps a tempo automator will take from start to
    /// ceiling, inclusive of the starting BPM. A non-positive step yields a
    /// single (start-only) step rather than diverging.
    static func automatorStepCount(startBPM: Int, stepBPM: Int, ceilingBPM: Int) -> Int {
        guard stepBPM > 0, ceilingBPM > startBPM else { return 1 }
        return (ceilingBPM - startBPM + stepBPM - 1) / stepBPM + 1
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
