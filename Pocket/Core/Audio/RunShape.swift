import Foundation

/// One of the four phases of a command-anchored run (ADR 0045), in the order it plays — the rows of
/// the run setup's Practice Settings (ADR 0221 D1) and the captions under its staircase.
enum RampPhase: CaseIterable, Identifiable {
    case warmup, command, reach, backoff

    var id: Self { self }

    /// The row's title. **Back off** everywhere, never "Back-off" or "Back-up" (ADR 0221 D5).
    var title: String {
        switch self {
        case .warmup: return "Warm-up"
        case .command: return "Command"
        case .reach: return "Reach"
        case .backoff: return "Back off"
        }
    }

    /// The caption under the phase's bars in the staircase.
    var caption: String {
        switch self {
        case .warmup: return "warm-up"
        case .command: return "command"
        case .reach: return "reach"
        case .backoff: return "back off"
        }
    }

    /// Whether the player can switch the phase off — every phase but command (ADR 0221 D2).
    var isOptional: Bool { self != .command }
}

/// The run's **shape** as the player sets it phase by phase (ADR 0221): which phases play, how many
/// rungs each draws and how long each holds — everything about a ramp except its tempos.
///
/// Rung counts are stored as **intermediate stops** (`warmupSteps == 0` ⇒ one warm-up rung, the
/// floor), the unit the stored reach and back-off counts always used. The Steps control shows the
/// rungs *drawn*, which `CommandRamp.rungs(steps:from:to:)` works out (D4). Holds are in intervals:
/// four bars on an exercise, one pass on a loop.
struct RunShape: Equatable {
    var includeWarmup = true
    var includeReach = true
    var includeBackoff = true
    var warmupSteps = 0
    var reachSteps = 0
    var backoffSteps = 0
    var warmupHold = 1
    /// The command hold — the dwell (ADR 0078).
    var dwell = 4
    var reachHold = 1
    var backoffHold = 1

    /// Every hold's range, in intervals — the dwell's 1…12 (ADR 0078), now shared (ADR 0221 D3).
    static let holdRange = 1...12

    /// Whether the phase plays. Command always does.
    func isOn(_ phase: RampPhase) -> Bool {
        switch phase {
        case .warmup: return includeWarmup
        case .command: return true
        case .reach: return includeReach
        case .backoff: return includeBackoff
        }
    }

    /// Switch an optional phase on or off. Command can't be switched off, so this ignores it.
    mutating func setOn(_ phase: RampPhase, _ isOn: Bool) {
        switch phase {
        case .warmup: includeWarmup = isOn
        case .command: break
        case .reach: includeReach = isOn
        case .backoff: includeBackoff = isOn
        }
    }

    /// Whether the run is command alone — every optional phase switched off.
    var isCommandOnly: Bool { !includeWarmup && !includeReach && !includeBackoff }

    /// The phase's hold, in intervals: each rung's for the optional phases, the dwell for command.
    func hold(_ phase: RampPhase) -> Int {
        switch phase {
        case .warmup: return warmupHold
        case .command: return dwell
        case .reach: return reachHold
        case .backoff: return backoffHold
        }
    }

    /// Set a hold, clamped into `holdRange` — except that a hold **already above** the ceiling keeps
    /// its value as its own ceiling, so a step down walks it down one at a time and a step up does
    /// nothing. Only a loop can hold one: folding its old reps per step into the holds (ADR 0221 D8)
    /// multiplies them out, and 4 reps × a dwell of 4 is 16 passes. Snapping that to 12 on the first
    /// tap would change what the loop plays because a button was touched.
    mutating func setHold(_ phase: RampPhase, _ value: Int) {
        let ceiling = max(Self.holdRange.upperBound, hold(phase))
        let clamped = min(ceiling, max(Self.holdRange.lowerBound, value))
        switch phase {
        case .warmup: warmupHold = clamped
        case .command: dwell = clamped
        case .reach: reachHold = clamped
        case .backoff: backoffHold = clamped
        }
    }

    /// The phase's stored intermediate-stop count, or `nil` for command, which is always one plateau.
    func steps(_ phase: RampPhase) -> Int? {
        switch phase {
        case .warmup: return warmupSteps
        case .command: return nil
        case .reach: return reachSteps
        case .backoff: return backoffSteps
        }
    }

    /// Set the phase's count from the number of **rungs** the player asked to draw.
    mutating func setRungs(_ phase: RampPhase, _ rungs: Int) {
        let stops = max(0, rungs - 1)
        switch phase {
        case .warmup: warmupSteps = stops
        case .command: break
        case .reach: reachSteps = stops
        case .backoff: backoffSteps = stops
        }
    }
}

/// The tempos a run's phases span — the half of a setup `RunShape` leaves out. Kept apart from the
/// shape because they are edited differently: a pin can be reset to auto, and command is clamped
/// against the floor.
struct RampTempos: Equatable {
    /// The warm-up floor — **Start at** on screen (ADR 0221 D5).
    var working: Int
    var command: Int
    var reach: Int
    var backoff: Int

    /// Where the back-off descends from: the reach when the run summits, else command itself.
    func summit(in shape: RunShape) -> Int {
        shape.includeReach && reach > command ? reach : command
    }

    /// The tempos a phase's rungs climb or descend between, for the rung limit (ADR 0221 D4).
    func span(of phase: RampPhase, in shape: RunShape) -> (from: Int, to: Int) {
        switch phase {
        case .warmup: return (working, command)
        case .command: return (command, command)
        case .reach: return (command, reach)
        case .backoff: return (summit(in: shape), backoff)
        }
    }

    /// Whether the phase has room to draw anything: a floor below command, a reach above it, a back
    /// off below it. Command always does.
    func hasRoom(for phase: RampPhase) -> Bool {
        switch phase {
        case .warmup: return command > working
        case .command: return true
        case .reach: return reach > command
        case .backoff: return backoff < command
        }
    }

    /// The rungs the phase draws at its stored count, clamped to its gap — the number its Steps
    /// control shows, which is always the number drawn (ADR 0221 D4).
    func rungs(of phase: RampPhase, in shape: RunShape) -> Int {
        guard let steps = shape.steps(phase) else { return 1 }
        let span = span(of: phase, in: shape)
        return CommandRamp.rungs(steps: steps, from: span.from, to: span.to)
    }

    /// The most rungs the phase can draw: seven, or the gap when that is smaller.
    func maxRungs(of phase: RampPhase, in shape: RunShape) -> Int {
        let span = span(of: phase, in: shape)
        return CommandRamp.rungs(steps: CommandRamp.maxRungs, from: span.from, to: span.to)
    }
}

extension CommandRamp {

    /// A ramp from a setup's tempos and shape. `backoffOverride` is passed separately because the ramp
    /// derives an unpinned back off itself, from the reach and floor it was given.
    init(tempos: RampTempos, shape: RunShape, backoffOverride: Int?,
         intervalCount: Int, unit: MetronomeIntervalUnit) {
        self.init(working: tempos.working, command: tempos.command, target: tempos.reach,
                  warmupSteps: max(0, shape.warmupSteps), intervalCount: intervalCount, unit: unit,
                  dwellIntervals: max(1, shape.dwell), includeBackoff: shape.includeBackoff,
                  reachSteps: max(0, shape.reachSteps), backoffSteps: max(0, shape.backoffSteps),
                  backoffOverride: backoffOverride,
                  includeWarmup: shape.includeWarmup, includeReach: shape.includeReach,
                  warmupHold: max(1, shape.warmupHold), reachHold: max(1, shape.reachHold),
                  backoffHold: max(1, shape.backoffHold))
    }

    /// Which bars each phase drew: a contiguous index range into `plateaus` per phase, and no entry
    /// for a phase that drew nothing. The staircase captions its phases and lights an open row's
    /// bars (ADR 0221 D1) from this.
    ///
    /// Recovered from the bars rather than carried on them, so it works on any ramp, fitted or not.
    /// The command plateau is the one **at** command — unique, since the warm-up climbs below it, the
    /// reach above and the back off below — falling back to the widest bar if none is. The summit is
    /// the highest bar; everything between command and the summit is reach, everything after it back
    /// off. With Reach off the highest bar is command itself, so there is no reach group.
    static func phaseRanges(of plateaus: [Plateau], command: Int) -> [RampPhase: Range<Int>] {
        guard !plateaus.isEmpty else { return [:] }
        let dwell = plateaus.firstIndex { $0.bpm == command }
            ?? plateaus.indices.max { plateaus[$0].intervals < plateaus[$1].intervals } ?? 0
        let summit = max(dwell, plateaus.indices.max { plateaus[$0].bpm < plateaus[$1].bpm } ?? dwell)
        var ranges: [RampPhase: Range<Int>] = [.command: dwell..<(dwell + 1)]
        if dwell > 0 { ranges[.warmup] = 0..<dwell }
        if summit > dwell { ranges[.reach] = (dwell + 1)..<(summit + 1) }
        if summit < plateaus.count - 1 { ranges[.backoff] = (summit + 1)..<plateaus.count }
        return ranges
    }
}
