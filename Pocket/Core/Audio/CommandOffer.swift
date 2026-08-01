import Foundation

/// Pure, UI-free **command revision** math (ADR 0079, widened by ADR 0134): after a training run, the
/// completion screen may offer to move `command` — *up* to the reach the run summited, or *down* to
/// the backoff the run settled at. The three questions this answers — *is there an offer, and which
/// way?*, *what command does accepting a raise produce?*, and *what does accepting a settle produce?*
/// — are the kind of boundary logic that breaks silently, so they live here, engine- and SwiftUI-free,
/// and are exhaustively unit-tested per AGENTS.md.
///
/// This is the same math the standalone post-run offer and the routine Done screen apply; centralising
/// it means every caller shares one rule.
///
/// **Never a verdict (ADR 0070).** The direction comes from the player's own self-rating, entered by
/// them on that screen. Nothing here measures how anything was played, and the offer this feeds is
/// opt-in and default off — the app proposes a revision, it never makes one.
enum CommandOffer {

    /// Which way the offer points. There is no `hold` case: "leave it alone" is the *absence* of an
    /// offer, and modelling it as a third direction would invite a row proposing to do nothing.
    enum Direction: Equatable {
        /// Move command **up** to the summited reach — the run was owned (ADR 0079).
        case raise
        /// Move command **down** toward the backoff — the run wasn't clean, and settling lower to
        /// consolidate is the technique, not a concession (ADR 0134).
        case settle
    }

    /// A revision the player accepted, and the tempo they accepted it at. The direction and its value
    /// travel together so a call site cannot pair "settle" with a number above command — the state
    /// that a bare `Int?` (today's `promoteTo:`) leaves representable.
    enum Revision: Equatable {
        case raise(Int)
        case settle(Int)

        /// The command to write.
        var value: Int {
            switch self {
            case .raise(let tempo), .settle(let tempo): return tempo
            }
        }

        var direction: Direction {
            switch self {
            case .raise: return .raise
            case .settle: return .settle
            }
        }
    }

    /// The direction the **rating alone** asks for, before any check that there's room to go there.
    ///
    /// Split out from `direction(mastery:command:reach:floor:ceiling:)` so the completion screen can
    /// re-pick a direction as the player taps the mastery dots without being handed the tempo anchors
    /// it has no other use for. The table lives here, tested, rather than in a `View`.
    static func preferredDirection(mastery: Int?) -> Direction? {
        switch mastery {
        case .none: return .raise
        case .some(3): return nil
        case .some(let rating): return rating <= 2 ? .settle : .raise
        }
    }

    /// Whether a raise has anywhere to go — a **ceiling-clamped** reach strictly above command, so a
    /// drill at the device ceiling with an overshooting auto-reach (command 300, reach 315) reads as
    /// "nothing to raise to" rather than offering a no-op (ADR 0079 §5).
    static func canRaise(command: Int, reach: Int, ceiling: Int) -> Bool {
        raisedCommand(reach: reach, ceiling: ceiling) > command
    }

    /// Whether a settle has anywhere to go — a floor strictly below command.
    static func canSettle(command: Int, floor: Int) -> Bool {
        command > floor
    }

    /// The offer's direction, or `nil` for no row at all — `preferredDirection` composed with the
    /// matching room check.
    ///
    /// The rating chooses the direction and the available room decides whether it survives
    /// (ADR 0134 §2):
    ///
    /// - **`nil` (unrated) ⇒ `.raise`** — *exactly* the pre-0134 behaviour, so a player who ignores
    ///   the dots sees the screen they already know. This ADR adds a path; it removes none.
    /// - **`0…2` ⇒ `.settle`**
    /// - **`3` ⇒ `nil`**, a deliberate dead band. "Fine" is not a request to change anything, and
    ///   offering either direction would put the app's thumb on a scale the player just declined to
    ///   tip.
    /// - **`4…5` ⇒ `.raise`**
    ///
    /// Then the direction needs somewhere to go: a raise wants a ceiling-clamped reach strictly above
    /// command (so a drill already at the device ceiling offers no no-op), a settle wants a floor
    /// strictly below it. Either way `nil` means the completion surface omits the row entirely.
    ///
    /// `mastery` is **the rating just entered on the completion screen**, never the stored one — a
    /// drill rated 5 months ago must not offer to raise after a run the player has this second rated 1.
    static func direction(mastery: Int?, command: Int, reach: Int,
                          floor: Int, ceiling: Int) -> Direction? {
        switch preferredDirection(mastery: mastery) {
        case .raise: return canRaise(command: command, reach: reach, ceiling: ceiling) ? .raise : nil
        case .settle: return canSettle(command: command, floor: floor) ? .settle : nil
        case .none: return nil
        }
    }

    /// The command a **default raise** produces: move up to the reach, but never past the device
    /// `ceiling`. It's also the default the editable stepper starts on. The reach then re-derives a bit
    /// above the new command (`TempoStretch`), and a pinned reach that command has caught up to is
    /// cleared by the model's `promoteCommand` — this function only computes the target command.
    static func raisedCommand(reach: Int, ceiling: Int) -> Int {
        min(ceiling, reach)
    }

    /// The command a **default settle** produces: drop to `backoff` — the tempo the run's own tail
    /// already played, minutes ago — floored at the instrument's `floor` and always strictly below the
    /// current `command`.
    ///
    /// Defaulting to the backoff is what keeps the offer a statement of fact rather than a judgement
    /// (ADR 0134 §3): `CommandRamp`'s backoff plateau is the last thing that sounded before the
    /// completion screen appeared, so the row describes something that happened rather than proposing
    /// a number the app invented.
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
