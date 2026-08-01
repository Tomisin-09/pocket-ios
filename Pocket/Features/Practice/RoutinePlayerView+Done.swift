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
                // Revisions are exercises-only in a routine (ADR 0079 §Scope/§7, unchanged by 0134);
                // the chosen value is already clamped by the Done screen's stepper. Both setters carry
                // their own invariants — `promoteCommand` drops a caught-up reach pin, `settleCommand`
                // pulls the warm-up floor down and drops a caught-up backoff pin (ADR 0134 §6).
                switch revision {
                case .raise(let tempo): exercise.promoteCommand(to: tempo)
                case .settle(let tempo): exercise.settleCommand(to: tempo)
                case .none: break
                }
            case .loop(let loop): loop.mastery = mastery
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
        RoutineBlockDoneView(title: stage.title,
                             initialMastery: mastery(for: stage),
                             anchors: revisionAnchors(for: stage),
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

    /// The tempo anchors the Done screen sizes its revision offer from (ADR 0079 §7, ADR 0134), or
    /// `nil` for a unit that carries no offer — a routine's **loop** blocks and songs, unchanged by
    /// 0134. Read live from the model rather than snapshotted: unlike a standalone run there is no
    /// completion value to preserve, and the block has already finished.
    func revisionAnchors(for stage: RoutineStage) -> CommandOffer.Anchors? {
        guard let exercise = stage.exercise else { return nil }
        let range = StandaloneMetronomeEngine.bpmRange
        return .init(command: exercise.command,
                     floor: range.lowerBound, ceiling: range.upperBound,
                     raiseTarget: CommandOffer.raisedCommand(reach: exercise.reachTempo,
                                                             ceiling: range.upperBound),
                     settleTarget: exercise.derivedBackoff)
    }
}
