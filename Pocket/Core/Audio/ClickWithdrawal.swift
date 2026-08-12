import Foundation

/// **The click withdraws itself** (ADR 0132) — the metronome thins out on a fixed eight-bar cycle so
/// the player carries the pulse rather than leaning on it, and hears what happened when it returns.
///
/// Nothing here is new audio machinery. A withdrawal is the same per-slot mechanism a strum pattern's
/// rests already use (ADR 0071 R5) pointed at whole bars: the grid keeps running, the phase never
/// moves, and some ticks simply don't sound. The click comes back exactly where it would have been,
/// because it never actually left the schedule.
///
/// Pure by design — Foundation only, no SwiftUI, no AVFoundation (AGENTS.md). The cycle table and the
/// bar arithmetic are exactly the kind of thing that breaks silently, so they are unit-tested and the
/// engine's part is reduced to handing this a tick index.
///
/// **It stays clear of ADR 0070.** The app removes its own signal and then says nothing: no drift is
/// measured, displayed, scored or recorded. The player draws their own conclusion, which is the
/// opposite of grading — it is the app declining to look.
enum ClickWithdrawal: String, CaseIterable, Identifiable {
    /// Every tick sounds, exactly as it did before ADR 0132.
    case off
    /// One bar in eight keeps only its downbeat.
    case gentle
    /// Two bars in eight thin out — one to its downbeat, one to silence.
    case standard
    /// Three bars in eight thin out, two of them to silence.
    case deep

    /// **Off by default, and this is a departure worth stating** (§5). The standing rule is
    /// opinionated defaults, but a metronome that stops clicking is indistinguishable from a
    /// metronome that has broken, and a first-run player who meets this before they have any reason
    /// to trust the app will file it as a bug. Withdrawal is a technique you adopt, not a behaviour
    /// you should have to discover and switch off. The opinionated part is that it is offered at all,
    /// and that its levels are three presets rather than a bar-count matrix.
    static let `default` = ClickWithdrawal.off

    /// The cycle is **always eight bars**, from the first musical downbeat, repeating for the run.
    /// Fixed rather than configurable so it lands on phrase boundaries (eight bars is the unit this
    /// app's library is actually built in), so the return is always in the same place and can be
    /// anticipated rather than ambushing the player, and so every cycle starts full — you cannot
    /// withdraw a pulse that was never established.
    static let cycleBars = 8

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: return "Off"
        case .gentle: return "Gentle"
        case .standard: return "Standard"
        case .deep: return "Deep"
        }
    }

    /// What this level does across the eight bars, in words — the Settings footer's second sentence,
    /// so the shape of the choice is readable without playing it first.
    var detail: String {
        switch self {
        case .off: return "The click sounds every bar."
        case .gentle: return "The last bar of each eight keeps only its downbeat."
        case .standard: return "Bars 5–6 keep only their downbeat; bars 7–8 fall silent."
        case .deep: return "Bars 3–4 keep only their downbeat; bars 5–8 fall silent."
        }
    }

    /// What the click does across one bar. A ladder in one direction — thinning, never chopping.
    ///
    /// `downbeatOnly` is the load-bearing middle rung and the reason this isn't a two-state feature.
    /// Going from a full click straight to nothing is a cliff: the player loses the pulse *and* the
    /// bar, and by the time the click returns they have no idea whether they drifted or simply lost
    /// count. A bar with only its downbeat still tells you where you are while withdrawing the thing
    /// that was doing the work — it takes away the crutch without taking away the map.
    enum Level: String, CaseIterable, Equatable {
        /// Every tick, exactly as today — meter accents, subdivisions if armed.
        case full
        /// Beat 1 of the bar, at `.accent`. Every other tick silent.
        case downbeatOnly
        /// Nothing.
        case silent

        /// The short static word the run caption carries while this level is in force (§7), or `nil`
        /// when there is nothing to say.
        ///
        /// This is the **accessibility carrier, not a nicety**: `BeatIndicator` is
        /// `accessibilityHidden(true)`, so without it the withdrawal is invisible to VoiceOver and a
        /// screen-reader user meets an unexplained silence. Static, never animated — a *pulsing*
        /// marker would itself be a visual metronome, and anything animated falls under Reduce
        /// Motion, hiding it from some of the people who most need to know why the room went quiet.
        /// (ADR 0157 retired this argument's third leg: `exerciseAnimates` now defaults **on**. The
        /// decision stands on the two reasons above, which never depended on the default.)
        var caption: String? {
            switch self {
            case .full: return nil
            case .downbeatOnly: return "Downbeats only"
            case .silent: return "Click withdrawn"
            }
        }
    }

    /// The cycle as its four bar-pairs (§2). Every level begins `full`, so the very start of a run
    /// always sounds normal and each cycle re-establishes the pulse before withdrawing it.
    ///
    /// **These counts are tunable; the level names are not** (§5). A raw value that encoded the
    /// mechanics — `twoOnTwoOff`, `fourBarGap` — would start lying the moment this table was tuned,
    /// and fixing it would become a data migration for what should be a one-line edit here.
    private var barPairs: [Level] {
        switch self {
        case .off: return [.full, .full, .full, .full]
        case .gentle: return [.full, .full, .full, .downbeatOnly]
        case .standard: return [.full, .full, .downbeatOnly, .silent]
        case .deep: return [.full, .downbeatOnly, .silent, .silent]
        }
    }

    /// The level in force on `bar`, counted from the drill's first musical downbeat (0-based).
    /// A negative index is the count-in, which is not part of the cycle and is never withdrawn.
    func level(atBar bar: Int) -> Level {
        guard bar >= 0 else { return .full }
        return barPairs[(bar % Self.cycleBars) / 2]
    }

    /// The bar a tick falls in, counted from the drill's first musical downbeat (§8).
    ///
    /// Negative before the drill begins. Integer division truncates toward zero, which would fold the
    /// last count-in bar onto bar 0, so this floors explicitly — the count-in must not be able to
    /// appear inside the cycle.
    static func barIndex(forTick tick: Int, originTick: Int,
                         ticksPerBeat: Int, beatsPerBar: Int) -> Int {
        let ticksPerBar = max(1, ticksPerBeat) * max(1, beatsPerBar)
        let offset = tick - originTick
        let quotient = offset / ticksPerBar
        return offset < 0 && offset % ticksPerBar != 0 ? quotient - 1 : quotient
    }

    /// What a withdrawal says about one **scheduled** tick, in the precedence chain
    /// `count-in > warning > withdrawal > strum pattern > meter` (§4).
    enum TickVerdict: Equatable {
        /// Withdrawal has nothing to say — the tick sounds as it otherwise would, from the strum
        /// pattern's slot or the meter's accent.
        case unchanged
        /// A `downbeatOnly` bar's beat 1: it sounds, at `.accent`, whatever the meter would have said.
        case downbeat
        /// Withdrawn. Schedule nothing — the grid keeps running and the phase never moves.
        case silent
    }

    /// Resolve one scheduled tick against the cycle.
    func verdict(forTick tick: Int, originTick: Int,
                 ticksPerBeat: Int, beatsPerBar: Int) -> TickVerdict {
        guard self != .off else { return .unchanged }
        let bar = Self.barIndex(forTick: tick, originTick: originTick,
                                ticksPerBeat: ticksPerBeat, beatsPerBar: beatsPerBar)
        switch level(atBar: bar) {
        case .full:
            return .unchanged
        case .silent:
            return .silent
        case .downbeatOnly:
            let ticksPerBar = max(1, ticksPerBeat) * max(1, beatsPerBar)
            let intoBar = ((tick - originTick) % ticksPerBar + ticksPerBar) % ticksPerBar
            return intoBar == 0 ? .downbeat : .silent
        }
    }

    /// The tick the cycle counts bar 0 from, given the tick it first became eligible on: the **next
    /// bar downbeat at or after** it (§8, as amended).
    ///
    /// Rounding up to a bar boundary is what keeps the cycle aligned to the meter. Withdrawal can
    /// become eligible mid-bar — the tier is switched on while the click runs, or a ramp that
    /// suspended it stops — and starting bar 0 wherever that happened to land would offset every
    /// later silent bar from the music by a fraction of a bar. The grid's tick 0 is a downbeat, so
    /// bar boundaries are the multiples of `ticksPerBar`.
    static func originTick(eligibleAt tick: Int, ticksPerBeat: Int, beatsPerBar: Int) -> Int {
        let ticksPerBar = max(1, ticksPerBeat) * max(1, beatsPerBar)
        let bars = Int((Double(max(0, tick)) / Double(ticksPerBar)).rounded(.up))
        return bars * ticksPerBar
    }

    /// The withdrawal actually in force, from the per-exercise override, the global default, and the
    /// three facts that veto it outright.
    ///
    /// **The exclusions live here, not in the UI** (§4). Hiding a control on a screen is presentation;
    /// these are the rule, and keeping them in one pure function is what makes them testable together.
    ///
    /// - `onMetronomeTool` — the **free-play metronome only** (§4, as amended 2026-08-05). Withdrawal
    ///   is opt-in per host rather than derived, so a screen that gains a metronome later cannot
    ///   inherit the behaviour by accident.
    /// - `rampRunning` — a moving tempo and a withdrawing click are two demands at once, and a click
    ///   that leaves during a climb takes away the reference just as the thing to measure against
    ///   changes. The click withdraws when it is a **steady** click.
    /// - `strumArmed` — a strum pattern's rhythm is the lesson, not the scaffolding; silencing it
    ///   removes the exercise rather than a crutch. Keyed on whether a schedule is *armed*, never on
    ///   the exercise's template, because with Settings ▸ "Strumming click follows the pattern" off a
    ///   strumming drill running a plain meter click is acoustically a metronome exercise. Unreachable
    ///   while `onMetronomeTool` gates everything, and kept because it is a decided rule that Slice 2's
    ///   per-exercise override could put back in reach.
    ///
    /// `exercise` is the raw stored override (§6): `nil` means **inherit** and can never be collapsed
    /// into `"off"`, or the global setting silently becomes a new-exercises-only preference. An
    /// unrecognised raw value inherits too, which is the safe reading of something a later build wrote.
    ///
    /// ADR 0132 Slice 1 has no `Exercise` field yet and every caller passes `nil`; the argument is here
    /// so the rule is written and tested once, and Slice 2 only has to supply it.
    static func resolve(exercise: String?, global: ClickWithdrawal, onMetronomeTool: Bool,
                        rampRunning: Bool, strumArmed: Bool) -> ClickWithdrawal {
        guard onMetronomeTool, !rampRunning, !strumArmed else { return .off }
        guard let exercise else { return global }
        return ClickWithdrawal(rawValue: exercise) ?? global
    }
}
