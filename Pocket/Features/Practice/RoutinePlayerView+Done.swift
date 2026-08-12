import SwiftUI

/// The routine player's **post-block Done screen** (ADR 0071 R4) — the surface itself, the two
/// command-revision offers it carries (ADR 0079 §7, ADR 0134), and the single commit that lands
/// mastery, the note and an accepted revision together.
///
/// Split out of `RoutinePlayerView.swift` when ADR 0134 gave the offer a second direction and the
/// host reached the 400-line cap CI's `--strict` lint enforces. A seam rather than an arbitrary cut:
/// everything here is the completion beat, and nothing else in the player touches it.
extension RoutinePlayerView {

    /// Commit the Done screen's optional mastery self-rating, inline note, and opt-in command revision
    /// in **one** action (the P3 lesson — no competing "Add entry" button), then advance. Mastery
    /// writes to the unit; the note writes a `JournalWriter` entry (which snapshots the unit's
    /// context); an accepted revision moves an exercise's command up to its reach or down toward its
    /// backoff. Each may be a no-op — an unchanged rating, an empty note, and an un-flipped toggle all
    /// commit nothing.
    func commitDone(_ stage: RoutineStage, mastery: Int?, note: String, kind: EntryKind,
                    revision: CommandOffer.Revision?) {
        if let owner = owner(for: stage) {
            switch owner {
            case .exercise(let exercise):
                exercise.mastery = mastery
                // The chosen value is already clamped by the Done screen's stepper. Both setters carry
                // their own invariants — `promoteCommand` drops a caught-up reach pin, `settleCommand`
                // pulls the warm-up floor down and drops a caught-up backoff pin (ADR 0134 §6).
                switch revision {
                case .raise(let tempo): exercise.promoteCommand(to: tempo)
                case .settle(let tempo): exercise.settleCommand(to: tempo)
                case .none: break
                }
            case .loop(let loop):
                loop.mastery = mastery
                // Loops by symmetry (ADR 0134 §8), differing only in unit: the screen works in whole
                // percent and the model in `×`, the same conversion the standalone screen makes.
                //
                // **No `speed` pull-down on a settle**, unlike the exercise floor. `LoopRunView`
                // lowers its local `working` because that is `@State` its own steppers keep at or
                // below command; the *model* needs nothing, because `Loop.rampFloor` is
                // `min(command - measuredWarmupGap, speed)` and so forces its own gap. A loop's
                // warm-up cannot invert the way an exercise's can (ADR 0134 §8, `Loop.settleCommand`).
                switch revision {
                case .raise(let percent): loop.promoteCommand(to: Double(percent) / 100)
                case .settle(let percent): loop.settleCommand(to: Double(percent) / 100)
                case .none: break
                }
            case .session, .standalone, .metronome:
                // All three unreachable: `owner(for:)` only ever builds a unit owner from a stage. A
                // session owner belongs to the whole sitting and is written from the summary screen
                // (ADR 0143); a standalone owner is never built from a stage at all, since a stage is
                // exactly the unit a standalone note declines to have (ADR 0155); and a metronome
                // owner exists only on the free-play screen, which no routine runs through (ADR
                // 0160). None has a
                // mastery or a command to revise — so there is nothing here to do but let the note
                // below be written.
                break
            }
            _ = JournalWriter.add(to: owner, text: note, kind: kind, into: modelContext)
            try? modelContext.save()
        }
        doneStage = nil
        haptic(.light)
        player.advance()
    }

    @ViewBuilder
    func doneView(for stage: RoutineStage) -> some View {
        let offer = revisionOffer(for: stage)
        RoutineBlockDoneView(title: stage.title,
                             initialMastery: mastery(for: stage),
                             anchors: offer?.anchors, unit: offer?.unit ?? .bpm,
                             isLast: player.upNext == nil,
                             upNext: upNextDescriptor()) { mastery, note, kind, revision in
            commitDone(stage, mastery: mastery, note: note, kind: kind, revision: revision)
        }
        // The Done screen sits outside the per-block session chrome, so give it its own way out —
        // Continue advances, but a player mid-routine needs to be able to leave from here too.
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                }
                .tint(PocketColor.textSecondary)
                .accessibilityLabel("Exit routine")
            }
        }
    }

    /// The tempo anchors the Done screen sizes its revision offer from **and the unit they read in**
    /// (ADR 0079 §7, ADR 0134), or `nil` for a unit that carries no offer at all.
    ///
    /// One function returning both because they cannot be allowed to disagree: anchors in percent
    /// rendered as BPM would offer to move a loop to "85", which is a number from a different axis.
    ///
    /// Read live from the model rather than snapshotted: unlike a standalone run there is no
    /// completion value to preserve, and the block has already finished.
    ///
    /// **Exhaustive over `payload`, deliberately not keyed on `stage.loop`** — that accessor returns
    /// the loop for ear and improvise blocks too, and neither has a command tempo to move: they are
    /// ramp-less, a jam is not run at a speed you own. `finishedBlock` already keeps them off this
    /// screen via `kind.isRampLess`, but naming them here means the rule survives that gate moving.
    func revisionOffer(for stage: RoutineStage)
        -> (anchors: CommandOffer.Anchors, unit: TempoUnit)? {
        switch stage.payload {
        case .exercise(let exercise):
            let range = StandaloneMetronomeEngine.bpmRange
            return (.init(command: exercise.command,
                          floor: range.lowerBound, ceiling: range.upperBound,
                          raiseTarget: CommandOffer.raisedCommand(reach: exercise.reachTempo,
                                                                  ceiling: range.upperBound),
                          settleTarget: exercise.derivedBackoff),
                    .bpm)
        case .loop(let loop):
            // Percent-of-original throughout (ADR 0082). `backoffPercent` is already derived in the
            // integer-percent domain `CommandRamp` computes the tail in, so the offer and the ramp
            // the run just played cannot drift by a percent (ADR 0134 §3/§8).
            let range = TempoMath.percentRange
            let reach = LoopCommandRamp.percent(loop.targetSpeed)
            return (.init(command: LoopCommandRamp.percent(loop.command),
                          floor: range.lowerBound, ceiling: range.upperBound,
                          raiseTarget: CommandOffer.raisedCommand(reach: reach,
                                                                  ceiling: range.upperBound),
                          settleTarget: loop.backoffPercent),
                    .percent)
        case .earLoop, .improviseLoop, .song, .rest:
            return nil
        }
    }
}
