import Foundation

/// Pure, UI-free **command revision** math (ADR 0079, widened by ADR 0134): after a training run, the
/// completion screen may offer to move `command` — up toward the reach the run summited, down toward
/// the backoff it settled at, or either way when the player hasn't said. The questions this answers —
/// *is there an offer, and how does it lean?* and *what range and starting value does that lean
/// imply?* — are the kind of boundary logic that breaks silently, so they live here, engine- and
/// SwiftUI-free, and are exhaustively unit-tested per AGENTS.md.
///
/// **Never a verdict (ADR 0070).** The lean comes from the player's own self-rating, entered by them
/// on that screen; the *number* is always theirs to choose. Nothing here measures how anything was
/// played, and the offer this feeds is opt-in and default off — the app proposes a range, never a
/// revision.
enum CommandOffer {

    /// How the offer **leans** — which is not the same as which way it can move.
    ///
    /// `open` is load-bearing: an unrated run gets a neutral prompt *and* a range spanning both
    /// directions, because the app has been told nothing and must not presume. A leaning offer is
    /// narrowed to its own side, so accepting it cannot land somewhere the copy didn't describe.
    enum Stance: Equatable {
        /// No lean — the player hasn't rated the run. Ranges across the instrument, starting where
        /// command already sits, so doing nothing changes nothing.
        case open
        /// Toward the summited reach — the run was owned (ADR 0079).
        case raise
        /// Toward the backoff — the run wasn't clean, and consolidating lower is the technique, not a
        /// concession (ADR 0134).
        case settle
    }

    /// A revision the player accepted, and the tempo they accepted it at. The direction and its value
    /// travel together so a call site cannot pair "settle" with a number above command — the state a
    /// bare `Int?` leaves representable. Derived from where the chosen value lands relative to command,
    /// which is what lets an `open` offer commit either way.
    enum Revision: Equatable {
        case raise(Int)
        case settle(Int)

        /// The command to write.
        var value: Int {
            switch self {
            case .raise(let tempo), .settle(let tempo): return tempo
            }
        }
    }

    /// Everything the completion screen needs to size an offer, gathered by the host from the model.
    /// Value-only, so the screen stays SwiftData-free and every range below stays pure.
    struct Anchors: Equatable {
        /// The tempo the drill sits at now — the pivot every range is measured from.
        let command: Int
        /// The instrument's bounds (BPM for an exercise, percent-of-original for a loop).
        let floor: Int
        let ceiling: Int
        /// Where a raise would start: the ceiling-clamped reach.
        let raiseTarget: Int
        /// Where a settle would start: the backoff this run's own tail played, floored.
        let settleTarget: Int
    }

    /// The range an offer may take and the value it opens on.
    struct Bounds: Equatable {
        let defaultTarget: Int
        let minValue: Int
        let maxValue: Int
    }

    /// The stance the **rating alone** asks for, before any check that there's room to go there.
    ///
    /// | `mastery` | stance |
    /// |---|---|
    /// | `nil` (unrated) | `.open` — the app has been told nothing, so it presumes nothing. |
    /// | `0…2` | `.settle` |
    /// | `3` | `nil` — a deliberate dead band. "Fine" is not a request to change anything, and leaning either way would put the app's thumb on a scale the player just declined to tip. |
    /// | `4…5` | `.raise` |
    ///
    /// Split out from `stance(mastery:anchors:)` so the completion screen can re-lean as the player
    /// taps the mastery dots without being handed anchors it has no other use for. The table lives
    /// here, tested, rather than in a `View`.
    ///
    /// `mastery` is **the rating just entered on the completion screen**, never the stored one — a
    /// drill rated 5 months ago must not lean toward a raise after a run the player has this second
    /// rated 1.
    static func preferredStance(mastery: Int?) -> Stance? {
        switch mastery {
        case .none: return .open
        case .some(3): return nil
        case .some(let rating): return rating <= 2 ? .settle : .raise
        }
    }

    /// The stance that survives its room check, or `nil` for no row at all.
    static func stance(mastery: Int?, anchors: Anchors) -> Stance? {
        guard let wanted = preferredStance(mastery: mastery),
              bounds(for: wanted, anchors: anchors) != nil
        else { return nil }
        return wanted
    }

    /// The range and starting value a stance implies, or `nil` when it has nowhere to go.
    ///
    /// - `.open` spans the whole instrument and **opens on `command` itself**, so a player who toggles
    ///   it on and commits without moving the stepper changes nothing. That is the honest neutral: the
    ///   app is not proposing a tempo, it is opening the axis.
    /// - `.raise` is narrowed to strictly above command, opening on the ceiling-clamped reach.
    /// - `.settle` is narrowed to strictly below command, opening on the backoff — the tempo the run's
    ///   own tail already played, minutes ago (ADR 0134 §3) — and reaching all the way to the floor
    ///   rather than stopping at that backoff, because the case this exists for is sometimes a drop of
    ///   twenty, not four (§4).
    static func bounds(for stance: Stance, anchors: Anchors) -> Bounds? {
        switch stance {
        case .open:
            guard anchors.floor < anchors.ceiling else { return nil }
            return Bounds(defaultTarget: anchors.command,
                          minValue: anchors.floor, maxValue: anchors.ceiling)
        case .raise:
            guard canRaise(anchors) else { return nil }
            return Bounds(defaultTarget: anchors.raiseTarget,
                          minValue: anchors.command + 1, maxValue: anchors.ceiling)
        case .settle:
            guard canSettle(anchors) else { return nil }
            return Bounds(defaultTarget: settledCommand(backoff: anchors.settleTarget,
                                                        floor: anchors.floor,
                                                        command: anchors.command),
                          minValue: anchors.floor, maxValue: anchors.command - 1)
        }
    }

    /// Whether a raise has anywhere to go — a **ceiling-clamped** reach strictly above command, so a
    /// drill at the device ceiling with an overshooting auto-reach (command 300, reach 315) reads as
    /// "nothing to raise to" rather than offering a no-op (ADR 0079 §5).
    static func canRaise(_ anchors: Anchors) -> Bool {
        min(anchors.ceiling, anchors.raiseTarget) > anchors.command
    }

    /// Whether a settle has anywhere to go — a floor strictly below command.
    static func canSettle(_ anchors: Anchors) -> Bool {
        anchors.command > anchors.floor
    }

    /// The revision a chosen value represents, or `nil` when it *is* the current command — which an
    /// `open` offer makes reachable, and which must commit nothing rather than a no-op write.
    static func revision(value: Int, command: Int) -> Revision? {
        if value > command { return .raise(value) }
        if value < command { return .settle(value) }
        return nil
    }

    /// The command a **default raise** produces: move up to the reach, but never past the device
    /// `ceiling`. The reach then re-derives a bit above the new command (`TempoStretch`), and a pinned
    /// reach that command has caught up to is cleared by the model's `promoteCommand` — this function
    /// only computes the target command.
    static func raisedCommand(reach: Int, ceiling: Int) -> Int {
        min(ceiling, reach)
    }

    /// The command a **default settle** produces: drop to `backoff` — the tempo the run's own tail
    /// already played — floored at the instrument's `floor` and always strictly below `command`.
    ///
    /// The `command - 1` clamp earns its place on a drill whose backoff *isn't* below command — one
    /// running with `includeBackoff` off, or carrying a stale pin — where the derived value can land
    /// on command and make accepting a no-op.
    static func settledCommand(backoff: Int, floor: Int, command: Int) -> Int {
        min(command - 1, max(floor, backoff))
    }

    // MARK: - The invariants a settle has to carry with it (ADR 0134 §6)

    /// The warm-up floor a settle to `command` implies.
    ///
    /// `Exercise.rampFloor` returns `workingTempo` **raw** once a command is measured, and
    /// `CommandRamp.plateaus` emits a warm-up only while `command > working`. A command settled to at
    /// or below working therefore yields a ramp that opens *at* command with no climb — the exact
    /// opposite of what the player asked for, and no error anywhere. Re-derive the floor beneath it.
    ///
    /// Pure and shared rather than written twice: the run screens hold their setup in `@State` and
    /// commit through `persist()` (ADR 0057), while the routine player writes the model directly, so
    /// **both** paths need this rule and neither can own it.
    ///
    /// Loops need no equivalent — `Loop.rampFloor` is `min(command - measuredWarmupGap, speed)`, so it
    /// forces its own gap and cannot invert.
    static func settledFloor(command: Int, working: Int) -> Int {
        command <= working ? TempoStretch.warmupFloorBPM(forCommand: command) : working
    }

    /// The backoff pin that survives a settle to `command` — `nil` once the pin has been caught up.
    ///
    /// `CommandRamp.plateaus` appends the tail only while `backoff < command`, so a pin sitting at or
    /// above the settled command deletes the backoff outright. Clearing reverts to the derived value —
    /// the same shape, and the same reason, as `promoteCommand`'s reach-pin clear (ADR 0075).
    ///
    /// Generic over the unit so an exercise's BPM `Int` pin and a loop's `×` `Double` pin share one
    /// rule; the run screens hold theirs as whole percent, which compares identically.
    static func survivingBackoffPin<Tempo: Comparable>(_ pin: Tempo?, command: Tempo) -> Tempo? {
        guard let pin, pin < command else { return nil }
        return pin
    }
}
