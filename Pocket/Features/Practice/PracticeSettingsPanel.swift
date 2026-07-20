import SwiftUI

/// The collapsible **Practice Settings** panel at the top of the exercise run setup (V1 feedback):
/// the three tempos — warm-up **working** floor, owned **command**, derived **reach** — plus the
/// nested **Steps** granularity, tucked behind one disclosure header so the run screen reads as
/// just the title, a compact summary, and the staircase by default. Tapping the header expands it,
/// mirroring how the `RoutineStepsControls` Steps panel it contains behaves.
///
/// The tempo edits still live in `ExerciseRunView`'s local state (committed only on Start / Save);
/// this view is a pure presentation shell, taking the values + clamp closures and the step bindings.
struct PracticeSettingsPanel: View {
    @Binding var expanded: Bool

    // Tempos — values are read-only here; edits route back through the caller's clamp closures.
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
    /// Whether the routine backs off below command after the summit. Default on.
    @Binding var includeBackoff: Bool
    let backoff: Int
    /// Whether the backoff floor is a manual pin (vs the auto derivation) — drives caption + reset.
    let backoffIsCustom: Bool
    let onStepBackoff: (Int) -> Void
    let onTypeBackoff: (Int) -> Void
    let onResetBackoff: () -> Void

    // Steps — bound straight through to the nested `RoutineStepsControls`.
    @Binding var stepsExpanded: Bool
    @Binding var warmupSteps: Int
    @Binding var reachSteps: Int
    @Binding var backoffSteps: Int
    /// The command-plateau dwell (ADR 0078) + its per-type caption, threaded to `RoutineStepsControls`.
    @Binding var dwell: Int
    let dwellCaption: String
    let warmupStepBPM: Int
    let hasReach: Bool
    let tint: Color
    /// Fired on any disclosure toggle (this panel's or the nested Steps') so the host plays a haptic.
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            header
            if expanded {
                tempos
                RoutineStepsControls(expanded: $stepsExpanded, warmupSteps: $warmupSteps,
                                     reachSteps: $reachSteps, backoffSteps: $backoffSteps,
                                     dwell: $dwell, dwellCaption: dwellCaption,
                                     warmupStepBPM: warmupStepBPM, reach: reach,
                                     hasReach: hasReach, hasBackoff: includeBackoff,
                                     tint: tint, onChange: onToggle)
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
        .accessibilityHint(expanded ? "Collapse" : "Expand to adjust tempos and steps")
    }

    /// One-line tempo digest for the collapsed header — the climb and the reach at a glance.
    private var summary: String {
        hasReach
            ? "\(working)→\(command) · reach \(reach) BPM"
            : "\(working)→\(command) BPM"
    }

    private var tempos: some View {
        VStack(spacing: 14) {
            EditableTempoRow(label: "Working", caption: "warm-up floor", value: working,
                             tint: tint, onStep: onStepWorking, onType: onTypeWorking)
            EditableTempoRow(label: "Command", caption: "fastest you own", value: command,
                             tint: tint, onStep: onStepCommand, onType: onTypeCommand)
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

    /// The on/off for the back-off tail (user-testing note 6). Off ⇒ the routine ends at command
    /// (or the reach) instead of easing down; on ⇒ the editable floor below appears.
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

    /// The Back-off caption: custom-vs-auto, mirroring `reachCaption`. Auto shows the drop below
    /// command; a pin reads "custom floor".
    private var backoffCaption: String {
        backoffIsCustom ? "custom floor" : "auto · −\(max(0, command - backoff)) BPM"
    }

    /// The Reach caption: custom-vs-auto (ADR 0075). Auto shows the derived stretch above command;
    /// a pin reads "custom goal" so the override state is legible at a glance.
    private var reachCaption: String {
        reachIsCustom ? "custom goal" : "auto · +\(max(0, reach - command)) BPM"
    }
}
