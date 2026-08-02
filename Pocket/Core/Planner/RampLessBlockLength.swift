import Foundation

/// **How long a block with no ramp runs** (ADR 0141).
///
/// Three block types have no staircase to run its course — ear training (ADR 0104), improvising over
/// a backing track (ADR 0135) and the freeform block (ADR 0136). Outside a routine that is the point
/// and they stay open-ended. *Inside* one they need a length, or the session cannot honestly say how
/// long it is: a four-block session whose third block runs until you feel like stopping is not a
/// 40-minute session.
///
/// Pure and value-based, because the interesting case is a **three-way** distinction that a single
/// optional can't carry and that fails silently in every direction:
///
/// | `plannedMinutes` | `usesAuthoredLength` | result |
/// |---|---|---|
/// | 12 | `false` | 12 — the session's allotment |
/// | 12 | `true`  | **open-ended** — the block declined the fit (ADR 0130 / 0141 L4) |
/// | `nil` | `false` | the mode's default — hand-authored, never sized by a session (L6) |
/// | `nil` | `true`  | **open-ended** |
///
/// The middle rows are the ones worth stating: `effectivePlannedMinutes` collapses both `true` rows to
/// `nil`, and a run screen reading only that could not tell "the player declined a length" from "no
/// session ever gave it one" — which are opposite intentions with opposite correct behaviours.
enum RampLessBlockLength {

    // MARK: - Defaults (ADR 0141 L6)
    //
    // Only the fallback for a block authored by hand. The real default is whatever the session
    // allotted; these apply when nothing did.

    /// Ear training: short, because internalising a phrase is attention-dense and goes stale.
    static let earMinutes = 5
    /// Improvising: longer, because a jam needs a run-up before anything useful comes out.
    static let improviseMinutes = 10
    /// The freeform block (ADR 0136, unbuilt): same reasoning as improvising.
    static let freeformMinutes = 10

    /// The default for a loop mode, or `nil` for a mode that runs a ramp and prices itself.
    static func defaultMinutes(for mode: LoopRunMode) -> Int? {
        switch mode {
        case .trainer: nil          // the ramp is the length; this rule doesn't apply
        case .ear: earMinutes
        case .improvise: improviseMinutes
        }
    }

    // MARK: - The rule

    /// How long this block runs, in minutes — or `nil` for **open-ended**, which is the ADR 0104 /
    /// 0135 behaviour preserved exactly as a choice rather than as the only option (L4).
    ///
    /// - Parameters:
    ///   - plannedMinutes: the block's raw allotment (`RoutineItem.plannedMinutes`), *not* its
    ///     effective one — this function needs to see the allotment and the decline separately.
    ///   - usesAuthoredLength: the block's decline-the-fit flag (ADR 0130).
    ///   - fallback: the mode's default, applied only when no session sized this block.
    static func minutes(plannedMinutes: Int?, usesAuthoredLength: Bool, fallback: Int?) -> Int? {
        guard !usesAuthoredLength else { return nil }
        guard let resolved = plannedMinutes ?? fallback, resolved > 0 else { return nil }
        return resolved
    }

    /// The same rule in seconds, for a run screen's clock.
    static func seconds(plannedMinutes: Int?, usesAuthoredLength: Bool,
                        fallback: Int?) -> TimeInterval? {
        minutes(plannedMinutes: plannedMinutes, usesAuthoredLength: usesAuthoredLength,
                fallback: fallback).map { TimeInterval($0) * 60 }
    }

    /// Whether an elapsed run has reached its planned length. Open-ended blocks never have (L2 — the
    /// block ends, the playing is never cut off, and an open-ended one simply never ends on its own).
    static func isUp(elapsed: TimeInterval, planned: TimeInterval?) -> Bool {
        guard let planned else { return false }
        return elapsed >= planned
    }

    /// Seconds still to run, floored at zero; `nil` when open-ended (nothing to count down).
    static func remaining(elapsed: TimeInterval, planned: TimeInterval?) -> TimeInterval? {
        guard let planned else { return nil }
        return max(0, planned - elapsed)
    }

    /// **When the block actually finishes** — the first loop-region boundary at or after the planned
    /// end (ADR 0141 L2: the block ends, the *playing* is never cut off mid-phrase).
    ///
    /// With nothing sounding — or a region of no length to cycle — there is no phrase to protect and
    /// the planned end stands. Otherwise the deadline rounds **up** to a whole number of cycles since
    /// playback began, which is why a block can overshoot its allotment by up to one region: the
    /// deliberate trade named in the ADR's risks, and the reason session sizing should read a
    /// ramp-less block's length as a floor rather than a ceiling.
    static func finishTime(plannedEnd: Date, playbackStart: Date?,
                           cycleSeconds: TimeInterval) -> Date {
        guard let playbackStart, cycleSeconds > 0 else { return plannedEnd }
        let elapsed = plannedEnd.timeIntervalSince(playbackStart)
        guard elapsed > 0 else { return plannedEnd }
        let cycles = (elapsed / cycleSeconds).rounded(.up)
        return playbackStart.addingTimeInterval(cycles * cycleSeconds)
    }

    /// How long one pass of a loop region takes at a given playback percent — the cycle length
    /// `finishTime` rounds up to. Zero when the region is empty, which reads as "no cycle to protect".
    static func cycleSeconds(regionSeconds: TimeInterval, percent: Int) -> TimeInterval {
        guard regionSeconds > 0, percent > 0 else { return 0 }
        return regionSeconds / (Double(percent) / 100)
    }

    /// The remaining-time readout — `m:ss`, counting down, and nothing else (L3: a mirror, not an
    /// arcade; no urgency, no colour change, no chasing). `nil` when open-ended, so the caller draws
    /// no clock at all rather than a dash.
    static func remainingLabel(elapsed: TimeInterval, planned: TimeInterval?) -> String? {
        guard let left = remaining(elapsed: elapsed, planned: planned) else { return nil }
        let total = Int(left.rounded(.up))
        return "\(total / 60):\(String(format: "%02d", total % 60)) left"
    }
}
