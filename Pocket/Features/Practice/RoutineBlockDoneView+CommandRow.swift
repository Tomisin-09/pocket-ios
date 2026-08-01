import SwiftUI

/// The Done screen's **command revision** row (ADR 0079 §7, widened by ADR 0134) — how the offer
/// leans, the copy each lean carries, and the editable value it commits.
///
/// Split out of `RoutineBlockDoneView.swift` when the row gained more than one lean and the host hit
/// the 400-line / 250-line-body caps CI's `--strict` lint enforces. The seam is the whole revision
/// offer: nothing else on the completion screen reads `revisionOn` / `revisionValue`.
extension RoutineBlockDoneView {

    /// The lean the current rating asks for, or `nil` for no row — recomputed as the player taps the
    /// mastery dots. The rating→stance table lives in `CommandOffer` (pure, tested); this only feeds
    /// it the anchors the host supplied.
    var activeStance: CommandOffer.Stance? {
        guard let anchors else { return nil }
        return CommandOffer.stance(mastery: mastery, anchors: anchors)
    }

    /// The range and starting value that lean implies.
    var activeBounds: CommandOffer.Bounds? {
        guard let anchors, let activeStance else { return nil }
        return CommandOffer.bounds(for: activeStance, anchors: anchors)
    }

    /// What Continue commits: `nil` when there's no row, the toggle is off, or the chosen value *is*
    /// the current command — which an `open` offer makes reachable and which must write nothing.
    /// Deriving the direction from where the value landed is what lets a neutral offer commit either
    /// way without the copy having promised one.
    var acceptedRevision: CommandOffer.Revision? {
        guard revisionOn, let anchors, activeStance != nil else { return nil }
        return CommandOffer.revision(value: revisionValue, command: anchors.command)
    }

    /// The opt-in **command revision** row — leaning whichever way the mastery tap asks for, or
    /// neutral when it hasn't been tapped. Default off; flipping it on commits the move atomically
    /// with Continue, so the single primary stays the only action (no competing CTA). An offer, never
    /// a verdict (ADR 0070).
    func revisionRow(_ stance: CommandOffer.Stance, _ bounds: CommandOffer.Bounds) -> some View {
        VStack(spacing: 12) {
            Toggle(isOn: $revisionOn) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(headline(stance))
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text(rationale(stance))
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            .tint(PocketColor.practice)
            if revisionOn { revisionStepper(bounds) }
        }
        .padding(12)
        .background(PocketColor.surfaceStandard, in: RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: revisionOn)
        .onChange(of: revisionOn) { _, _ in haptic(.light) }
    }

    /// The row's headline — **never carrying a tempo value**.
    ///
    /// The prompt names the *move*; the number is the player's to choose, on the stepper below. A
    /// headline like "Move command to 106" states the app's proposal *as* the offer, which reads as a
    /// verdict dressed up as a question — and is flatly wrong on an unrated run, where the app has
    /// been told nothing and has no business leaning either way.
    func headline(_ stance: CommandOffer.Stance) -> String {
        switch stance {
        case .open: return "Change the command tempo"
        case .raise: return "Increase the command tempo"
        case .settle: return "Settle or reduce the command tempo"
        }
    }

    /// The supporting line. Each states a **fact about the run that just happened**, or nothing at all
    /// — never a judgement of it. No "you struggled", no suggestion to try something easier (§5).
    func rationale(_ stance: CommandOffer.Stance) -> String {
        switch stance {
        case .open: return "Up or down — wherever you actually own it."
        case .raise: return "You summited it this run."
        case .settle: return "Clean beats fast. Consolidating lower is progress, not a setback."
        }
    }

    /// The command adjuster shown once the revision is on — nudge the target within the stance's
    /// range. `StepperButton` owns its own press/hold haptics, so the clamp closures stay pure.
    func revisionStepper(_ bounds: CommandOffer.Bounds) -> some View {
        HStack(spacing: 16) {
            Text("New command")
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
            Spacer()
            StepperButton(symbol: "minus", label: "Lower new command", tint: PocketColor.practice) {
                revisionValue = max(bounds.minValue, revisionValue - 1)
            }
            Text(unit.inline(revisionValue))
                .font(.pocketMono(.title3))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(minWidth: 52)
                .contentTransition(.numericText())
            StepperButton(symbol: "plus", label: "Raise new command", tint: PocketColor.practice) {
                revisionValue = min(bounds.maxValue, revisionValue + 1)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
}
