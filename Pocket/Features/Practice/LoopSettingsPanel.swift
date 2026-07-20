import SwiftUI

/// The collapsible **Practice Settings** panel for the loop run setup — the loop counterpart of
/// `PracticeSettingsPanel`, so a loop run reads as just its title, a compact summary, and the
/// staircase by default, rather than every control expanded (user feedback, ADR 0071). Behind the
/// disclosure sit the two tempos (**working** floor, owned **command**, in % of original) with the
/// derived **reach**, the **reps per step**, and the nested **Steps** granularity.
///
/// The edits still live in `LoopRunView`'s local state (committed only on Start / Save); this view is
/// a pure presentation shell, taking the values + clamp closures and the step / reps bindings.
struct LoopSettingsPanel: View {
    @Binding var expanded: Bool

    // Tempos (percent of original) — read-only here; edits route through the caller's clamps.
    let working: Int
    let command: Int
    let reach: Int
    /// Whether the reach is a manual pin (vs the auto derivation) — drives the caption + reset button.
    let reachIsCustom: Bool
    let onStepWorking: (Int) -> Void
    let onTypeWorking: (Int) -> Void
    let onStepCommand: (Int) -> Void
    let onTypeCommand: (Int) -> Void
    let onStepReach: (Int) -> Void
    let onTypeReach: (Int) -> Void
    let onResetReach: () -> Void

    // Back-off (user-testing note 6) — an on/off for the tail below command, with an editable floor.
    /// Whether the ramp backs off below command after the summit. Default on.
    @Binding var includeBackoff: Bool
    let backoff: Int
    /// Whether the backoff floor is a manual pin (vs the auto derivation) — drives caption + reset.
    let backoffIsCustom: Bool
    let onStepBackoff: (Int) -> Void
    let onTypeBackoff: (Int) -> Void
    let onResetBackoff: () -> Void

    // Reps per step + the nested Steps controls.
    @Binding var repsPerStep: Int
    let repsRange: ClosedRange<Int>
    @Binding var stepsExpanded: Bool
    @Binding var warmupSteps: Int
    @Binding var reachSteps: Int
    @Binding var backoffSteps: Int
    /// The command-plateau dwell (ADR 0078) + its per-type caption ("≈ N passes at command").
    @Binding var dwell: Int
    let dwellCaption: String
    let warmupStepBPM: Int
    let hasReach: Bool
    let tint: Color
    /// Fired on any disclosure toggle or reps change so the host plays a haptic.
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            header
            if expanded {
                tempos
                repsRow
                RoutineStepsControls(expanded: $stepsExpanded, warmupSteps: $warmupSteps,
                                     reachSteps: $reachSteps, backoffSteps: $backoffSteps,
                                     dwell: $dwell, dwellCaption: dwellCaption,
                                     warmupStepBPM: warmupStepBPM, reach: reach,
                                     hasReach: hasReach, hasBackoff: includeBackoff,
                                     tint: tint, stepUnit: "%", onChange: onToggle)
            }
        }
    }

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            onToggle()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Practice Settings")
                        .font(.futura(.subheadline, weight: .semibold))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text(summary)
                        .font(.futura(.caption2))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(PocketColor.textSecondary)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Practice settings, \(summary)")
        .accessibilityHint(expanded ? "Collapse" : "Expand to adjust tempos, reps and steps")
    }

    /// One-line digest for the collapsed header — the climb and the reach at a glance (% of original).
    private var summary: String {
        hasReach ? "\(working)→\(command) · reach \(reach)%" : "\(working)→\(command)%"
    }

    private var tempos: some View {
        VStack(spacing: 14) {
            EditableTempoRow(label: "Working", caption: "warm-up floor (% of original)",
                             value: working, tint: tint,
                             onStep: onStepWorking, onType: onTypeWorking)
            EditableTempoRow(label: "Command", caption: "fastest you own (% of original)",
                             value: command, tint: tint,
                             onStep: onStepCommand, onType: onTypeCommand)
            EditableTempoRow(label: "Reach", caption: reachCaption, value: reach, tint: tint,
                             onStep: onStepReach, onType: onTypeReach)
            if reachIsCustom {
                resetButton(action: onResetReach, hint: "Clear the custom reach; use the auto-derived goal")
            }
            backoffToggle
            if includeBackoff {
                EditableTempoRow(label: "Back-off", caption: backoffCaption, value: backoff,
                                 tint: tint, onStep: onStepBackoff, onType: onTypeBackoff)
                if backoffIsCustom {
                    resetButton(action: onResetBackoff,
                                hint: "Clear the custom back-off; use the auto-derived floor")
                }
            }
        }
    }

    /// The Reach caption: the custom-vs-auto distinction (ADR 0075). Auto shows the derived
    /// stretch above command; a pin reads "custom" so the override state is legible at a glance.
    private var reachCaption: String {
        reachIsCustom ? "custom goal (% of original)" : "auto · +\(max(0, reach - command))%"
    }

    /// The on/off for the back-off tail (user-testing note 6). Off ⇒ the run ends at command (or the
    /// reach) instead of easing down; on ⇒ the editable floor below appears.
    private var backoffToggle: some View {
        Toggle(isOn: $includeBackoff) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Back off")
                    .font(.futura(.subheadline)).foregroundStyle(PocketColor.textPrimary)
                Text("finish below command, on control not the edge")
                    .font(.futura(.caption2)).foregroundStyle(PocketColor.textSecondary)
            }
        }
        .tint(tint)
        .accessibilityHint("Ease the tempo down after the summit to finish on clean control")
    }

    /// Shared reset-to-auto affordance for the pinned reach / back-off rows.
    private func resetButton(action: @escaping () -> Void, hint: String) -> some View {
        Button(action: action) {
            Label("Reset to auto", systemImage: "arrow.uturn.backward")
                .font(.futura(.caption)).foregroundStyle(tint)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .accessibilityHint(hint)
    }

    /// The Back-off caption: custom-vs-auto, mirroring `reachCaption` (% of original).
    private var backoffCaption: String {
        backoffIsCustom ? "custom floor (% of original)" : "auto · −\(max(0, command - backoff))%"
    }

    /// How many loop passes each step holds before the tempo bumps (ADR 0046 Phase B).
    private var repsRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Reps per step")
                    .font(.futura(.subheadline)).foregroundStyle(PocketColor.textPrimary)
                Text(repsPerStep == 1 ? "one loop, then step up" : "\(repsPerStep) loops, then step up")
                    .font(.futura(.caption2)).foregroundStyle(PocketColor.textSecondary)
            }
            Spacer()
            StepperButton(symbol: "minus", label: "Fewer reps per step", tint: tint) {
                repsPerStep = max(repsRange.lowerBound, repsPerStep - 1)
                onToggle()
            }
            Text("\(repsPerStep)")
                .font(.pocketMono(.title3)).foregroundStyle(PocketColor.textPrimary)
                .frame(width: 44).contentTransition(.numericText())
            StepperButton(symbol: "plus", label: "More reps per step", tint: tint) {
                repsPerStep = min(repsRange.upperBound, repsPerStep + 1)
                onToggle()
            }
        }
    }
}
