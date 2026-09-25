import Foundation

/// The line under a staircase that says how long the run is (ADR 0221 D10): `≈ 1 min 5 s · 16 bars`.
///
/// Only the **wording** lives here. The seconds come from `SessionEstimate.seconds` or
/// `LoopEstimate.seconds`, read off the ramp the staircase draws, so the line can't disagree with the
/// planner; the count is the ramp's own. Pure and unit-tested because rounding is the part that goes
/// wrong quietly — a "≈ 0 s", or a ten-minute run that reads "10 min 0 s".
///
/// It is a length, not a target: nothing compares it with anything (ADR 0070).
enum RunLength {

    /// What the count after the time counts.
    enum Unit {
        /// Metronome bars — an exercise.
        case bars
        /// Passes through a loop's region.
        case passes

        /// The word for `count` of them: `bar` / `bars`, `pass` / `passes`.
        func noun(_ count: Int) -> String {
            switch self {
            case .bars: return count == 1 ? "bar" : "bars"
            case .passes: return count == 1 ? "pass" : "passes"
            }
        }

        /// `16 bars`, `1 pass`.
        func label(_ count: Int) -> String { "\(count) \(noun(count))" }
    }

    /// Runs this long or longer are stated in whole minutes; shorter ones to the nearest 5 seconds.
    static let wholeMinutesFrom: Double = 600
    /// The rounding step below `wholeMinutesFrom`, and the least the line will ever say.
    static let secondsStep = 5

    /// `≈ 45 s`, `≈ 3 min 10 s`, `≈ 2 min`, `≈ 12 min`. Never `≈ 0 s`: a run shorter than the step
    /// reads as the step. A value that rounds up to ten minutes switches to whole minutes, so it reads
    /// `≈ 10 min` rather than `≈ 10 min 0 s`.
    static func duration(seconds: Double) -> String {
        let raw = max(0, seconds.isFinite ? seconds : 0)
        let step = Double(secondsStep)
        let stepped = (raw / step).rounded() * step
        if stepped >= wholeMinutesFrom {
            return "≈ \(Int((raw / 60).rounded())) min"
        }
        let total = max(secondsStep, Int(stepped))
        let minutes = total / 60
        let remainder = total % 60
        if minutes == 0 { return "≈ \(remainder) s" }
        return remainder == 0 ? "≈ \(minutes) min" : "≈ \(minutes) min \(remainder) s"
    }

    /// The whole line: the duration, then the exact count.
    static func label(seconds: Double, count: Int, unit: Unit) -> String {
        "\(duration(seconds: seconds)) · \(unit.label(max(0, count)))"
    }

    /// The line for an exercise ramp: seconds priced by `SessionEstimate` at each plateau's own tempo,
    /// and the bars it holds. A seconds-counted ramp has no bars to count, so it states the time alone.
    static func exercise(_ ramp: CommandRamp, beatsPerBar: Int) -> String {
        let seconds = SessionEstimate.seconds(forRamp: ramp, beatsPerBar: beatsPerBar)
        guard ramp.unit == .bars else { return duration(seconds: seconds) }
        return label(seconds: seconds, count: ramp.totalIntervals * max(1, ramp.intervalCount),
                     unit: .bars)
    }

    /// The line for a loop ramp: seconds priced by `LoopEstimate` at each plateau's own speed over the
    /// loop's region, and the passes it holds (`≈ 2 min 40 s · 12 passes`). A loop whose song hasn't
    /// resolved has no region to price, so it states the passes alone rather than a floor of `≈ 5 s`.
    static func loop(_ ramp: CommandRamp, regionSeconds: Double) -> String {
        let passes = ramp.totalIntervals * max(1, ramp.intervalCount)
        let seconds = LoopEstimate.seconds(forRamp: ramp, regionSeconds: regionSeconds)
        guard seconds > 0 else { return Unit.passes.label(passes) }
        return label(seconds: seconds, count: passes, unit: .passes)
    }
}
