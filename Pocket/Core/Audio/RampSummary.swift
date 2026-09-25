import Foundation

/// The words Practice Settings uses for a run (ADR 0221): the collapsed header's one-line summary
/// (D5), each phase row's summary (D1), and the captions under the steps and holds. Pure, and tested,
/// because generated prose is where a screen goes quietly wrong — a count that doesn't match the bars,
/// or "1 steps".
///
/// Everything is in the unit the setup counts in: BPM and bars on an exercise, percent and passes on
/// a loop.
struct RampSummary {
    let tempos: RampTempos
    let shape: RunShape
    /// Whether the reach is the auto derivation rather than a pin — "(auto)" in its row.
    let reachIsAuto: Bool
    /// Whether the back off is the auto derivation rather than a pin.
    let backoffIsAuto: Bool
    /// BPM or percent.
    let tempoUnit: TempoUnit
    /// What a hold is counted in on screen: bars or passes.
    let holdUnit: RunLength.Unit
    /// Units per hold interval — four bars on an exercise, one pass on a loop.
    let unitsPerInterval: Int

    /// A hold of `intervals`, in the unit the player counts: `8 bars`, `3 passes`.
    func holdLabel(_ intervals: Int) -> String {
        holdUnit.label(max(1, intervals) * max(1, unitsPerInterval))
    }

    // MARK: - The collapsed header (D5)

    /// The header's one line, naming only the phases that play: `51 → 61 · reach 65 · back to 55 BPM`,
    /// or, for a run of command alone, `61 BPM, steady · 16 bars`.
    var header: String {
        if shape.isCommandOnly {
            return "\(tempoUnit.signpost(tempos.command)), steady · \(holdLabel(shape.dwell))"
        }
        let climbs = shape.includeWarmup && tempos.hasRoom(for: .warmup)
        var parts = [climbs ? "\(inline(tempos.working)) → \(inline(tempos.command))"
                            : inline(tempos.command)]
        if shape.includeReach, tempos.hasRoom(for: .reach) { parts.append("reach \(inline(tempos.reach))") }
        if shape.includeBackoff, tempos.hasRoom(for: .backoff) {
            parts.append("back to \(inline(tempos.backoff))")
        }
        let line = parts.joined(separator: " · ")
        return tempoUnit == .bpm ? "\(line) BPM" : line
    }

    // MARK: - Phase rows (D1)

    /// A phase row's one line: what the phase will play, or, when it's off, what the run does
    /// without it.
    func row(_ phase: RampPhase) -> String {
        guard shape.isOn(phase) else { return "off · \(offMeaning(phase))" }
        switch phase {
        case .command:
            return "\(tempoUnit.signpost(tempos.command)) · \(holdLabel(shape.dwell))"
        case .warmup:
            guard tempos.hasRoom(for: .warmup) else { return "starts at command · nothing below it" }
            return "\(inline(tempos.working)) → \(inline(tempos.command)) · \(rungsAndHold(.warmup))"
        case .reach:
            guard tempos.hasRoom(for: .reach) else { return "nothing above command" }
            let auto = reachIsAuto ? " (auto)" : ""
            return "\(tempoUnit.signpost(tempos.reach))\(auto) · \(rungsAndHold(.reach))"
        case .backoff:
            guard tempos.hasRoom(for: .backoff) else { return "nothing below command" }
            return "\(tempoUnit.signpost(tempos.backoff)) · \(rungsAndHold(.backoff))"
        }
    }

    /// What the run does with the phase switched off.
    func offMeaning(_ phase: RampPhase) -> String {
        switch phase {
        case .warmup: return "the run starts straight at command"
        case .command: return ""
        case .reach: return "the run never goes above command"
        case .backoff: return "the run ends at its highest tempo"
        }
    }

    // MARK: - Control captions

    /// The Steps control's caption for a phase at its current rung count.
    func stepsCaption(_ phase: RampPhase) -> String {
        let rungs = tempos.rungs(of: phase, in: shape)
        switch phase {
        case .warmup:
            guard rungs > 1 else { return "one rung, then command" }
            let gap = tempos.command - tempos.working
            let each = max(1, Int((Double(gap) / Double(rungs)).rounded()))
            return "about +\(tempoUnit.inline(each)) \(tempoUnit == .bpm ? "BPM " : "")a rung"
        case .command: return ""
        case .reach: return rungs > 1 ? "ease up in stages" : "one jump up"
        case .backoff: return rungs > 1 ? "ease back down" : "one drop down"
        }
    }

    /// The hold control's caption. Command's says so when a session has fitted the hold to its block
    /// (ADR 0129), so the stepper can't claim a length the run won't play.
    func holdCaption(_ phase: RampPhase, playedDwell: Int? = nil) -> String {
        switch phase {
        case .warmup: return "how long each rung holds"
        case .command:
            if let playedDwell, playedDwell != shape.dwell {
                return "\(holdLabel(playedDwell)) in this session"
            }
            return "where the reps count"
        case .reach: return "a brief touch, so keep it short"
        case .backoff: return "finish on control, not the edge"
        }
    }

    /// A tempo control's caption for an auto-or-pinned value: `auto · +4 BPM`, or `custom`.
    func pinCaption(_ phase: RampPhase) -> String {
        switch phase {
        case .reach:
            return reachIsAuto ? "auto · +\(signed(tempos.reach - tempos.command))" : "custom"
        case .backoff:
            return backoffIsAuto ? "auto · −\(signed(tempos.command - tempos.backoff))" : "custom"
        case .warmup: return "the floor you climb from"
        case .command: return "fastest you own clean"
        }
    }

    // MARK: - Pieces

    private func rungsAndHold(_ phase: RampPhase) -> String {
        let rungs = tempos.rungs(of: phase, in: shape)
        let steps = rungs == 1 ? "1 step" : "\(rungs) steps"
        return "\(steps) · \(holdLabel(shape.hold(phase))) each"
    }

    /// A bare tempo in a list: `61` for BPM (the line ends in the unit), `85%` for a loop.
    private func inline(_ value: Int) -> String { tempoUnit.inline(value) }

    /// A difference with its unit: `4 BPM`, `5%`.
    private func signed(_ value: Int) -> String {
        tempoUnit == .bpm ? "\(max(0, value)) BPM" : "\(max(0, value))%"
    }
}
