import SwiftUI

/// The Done screen's **command revision** row (ADR 0079 §7, widened by ADR 0134) — which direction it
/// points, the copy each direction carries, and the editable value it commits.
///
/// Split out of `RoutineBlockDoneView.swift` when the row gained a second direction and the host hit
/// the 400-line / 250-line-body caps CI's `--strict` lint enforces. The seam is the whole revision
/// offer: nothing else on the completion screen reads `revisionOn` / `revisionValue`.
extension RoutineBlockDoneView {

    /// The config the current rating asks for, or `nil` for no row — the rating→direction table lives
    /// in `CommandOffer` (pure, tested); this only maps the answer onto the two configs the host
    /// supplied. A direction with no room arrives as a `nil` config and correctly yields no row.
    static func config(raise: CommandConfig?, settle: CommandConfig?,
                       mastery: Int?) -> CommandConfig? {
        switch CommandOffer.preferredDirection(mastery: mastery) {
        case .raise: return raise
        case .settle: return settle
        case .none: return nil
        }
    }

    /// The live config — recomputed as the player taps the mastery dots.
    var activeConfig: CommandConfig? {
        Self.config(raise: raise, settle: settle, mastery: mastery)
    }

    /// What Continue commits: `nil` when there's no row or the toggle is off, else the active
    /// direction paired with the chosen value. Pairing them here is what stops a stale `revisionValue`
    /// from ever being committed against the wrong direction.
    var acceptedRevision: CommandOffer.Revision? {
        guard revisionOn, let config = activeConfig else { return nil }
        switch config.direction {
        case .raise: return .raise(revisionValue)
        case .settle: return .settle(revisionValue)
        }
    }

    /// The opt-in **command revision** row (ADR 0079 §7, widened by ADR 0134) — offered in whichever
    /// direction the mastery tap asks for. Default off; flipping it on commits the move atomically
    /// with Continue, so the single primary stays the only action (no competing CTA). The target
    /// defaults to the reach (raise) or the backoff the run just played (settle) and is **editable**
    /// via a ±/typed stepper once on. Neutral framing — an offer, never a verdict (ADR 0070).
    func revisionRow(_ config: CommandConfig) -> some View {
        VStack(spacing: 12) {
            Toggle(isOn: $revisionOn) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(headline(config))
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text(rationale(config))
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            .tint(PocketColor.practice)
            if revisionOn { revisionStepper(config) }
        }
        .padding(12)
        .background(PocketColor.surfaceStandard, in: RoundedRectangle(cornerRadius: 12))
        .animation(.easeInOut(duration: 0.2), value: revisionOn)
        .onChange(of: revisionOn) { _, _ in haptic(.light) }
    }

    /// The row's headline. "Settle" rather than "Move … down": the word names the technique, and the
    /// difference between settling at a tempo and *dropping* to one is the whole framing (ADR 0134 §5).
    func headline(_ config: CommandConfig) -> String {
        let value = config.unit.inline(revisionValue)
        switch config.direction {
        case .raise: return "Move command to \(value)"
        case .settle: return "Settle command at \(value)"
        }
    }

    /// The supporting line. Both state a **fact about the run that just happened** rather than a
    /// judgement of it — the settle copy points at the backoff the tail actually played, so the row
    /// describes something the player heard minutes ago (ADR 0134 §3). Never "you struggled", never a
    /// suggestion to try something easier.
    func rationale(_ config: CommandConfig) -> String {
        switch config.direction {
        case .raise: return "You summited it this run — bump the drill up."
        case .settle: return "Clean beats fast. You finished the run here — own it, then climb again."
        }
    }

    /// The custom-command adjuster shown when the revision is on — nudge the target within the
    /// config's range. `StepperButton` owns its own press/hold haptics, so the clamp closures stay
    /// pure.
    func revisionStepper(_ config: CommandConfig) -> some View {
        HStack(spacing: 16) {
            Text("New command")
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
            Spacer()
            StepperButton(symbol: "minus", label: "Lower new command", tint: PocketColor.practice) {
                revisionValue = max(config.minValue, revisionValue - 1)
            }
            Text(config.unit.inline(revisionValue))
                .font(.pocketMono(.title3))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(minWidth: 52)
                .contentTransition(.numericText())
            StepperButton(symbol: "plus", label: "Raise new command", tint: PocketColor.practice) {
                revisionValue = min(config.maxValue, revisionValue + 1)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

}
