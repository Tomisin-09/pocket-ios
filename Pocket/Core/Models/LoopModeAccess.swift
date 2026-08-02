import Foundation

/// **Which practice modes a loop qualifies for** (ADR 0138).
///
/// There is no such thing as a loop that is globally ready or not ready to practise. There are
/// *modes*, and each has its own precondition — so the gate belongs to the mode, not to the loop
/// (G1). Before this, one test (`commandTempo != nil`) written for the **trainer** was inherited by
/// every mode that came after it, which put ear training — the one mode you can do with no
/// instrument in hand — behind a measurement you can only make **by playing the passage on your
/// instrument**.
///
/// Pure and value-based so each precondition can be unit-tested without a store or a screen: these
/// are exactly the predicates that break *silently*, by offering a mode that can't run or hiding one
/// that could.
enum LoopModeAccess {

    /// The facts a precondition is decided from — deliberately a small value rather than the `Loop`,
    /// so the rules are testable without SwiftData and can't quietly start reading something else.
    struct Facts: Equatable {
        /// A command tempo has been set: the loop has been *measured* (ADR 0082/0039).
        var hasCommandTempo: Bool
        /// The loop's audio can actually be played — it has a song, and that song isn't an Apple
        /// Music catalog item (ADR 0001: catalog audio is browse/metadata only). The same condition
        /// `AddRoutineUnitSheet.playableSongs` already applies to the Songs bucket.
        var audioResolves: Bool
    }

    /// Whether `mode` can run against a loop with these facts (G2).
    ///
    /// The `switch` is deliberately **exhaustive with no `default`**: when ADR 0135 adds
    /// `.improvise`, this stops compiling until its precondition (`isBackingTrack` — the flag *is*
    /// the requirement) is stated here. A `default` would silently hand the new mode whichever rule
    /// happened to be nearest, which is precisely how the trainer's gate ended up on ear training.
    static func allows(_ mode: LoopRunMode, _ facts: Facts) -> Bool {
        switch mode {
        // The ramp is built around the command tempo; without one there is no staircase to run.
        case .trainer: facts.hasCommandTempo
        // No tempo, no flag. If it can be heard, it can be sung back.
        case .ear: facts.audioResolves
        }
    }
}

extension LoopModeAccess.Facts {
    /// Read the facts off a live loop. A loop with **no song** has no audio to play, so it qualifies
    /// for no mode that needs sound — correct, and the reason this isn't just a `song != nil` check.
    init(_ loop: Loop) {
        self.init(hasCommandTempo: loop.commandTempo != nil,
                  audioResolves: loop.song.map { $0.ref.source != .appleMusic } ?? false)
    }
}

extension LoopModeAccess {
    /// Convenience for the call sites that hold a live loop.
    static func allows(_ mode: LoopRunMode, _ loop: Loop) -> Bool {
        allows(mode, Facts(loop))
    }

    /// The modes this loop qualifies for, in menu order — what a row offers (G4).
    static func modes(for loop: Loop) -> [LoopRunMode] {
        LoopRunMode.allCases.filter { allows($0, loop) }
    }
}
