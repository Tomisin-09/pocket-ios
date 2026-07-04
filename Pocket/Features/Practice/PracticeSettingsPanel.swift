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
    let onStepWorking: (Int) -> Void
    let onTypeWorking: (Int) -> Void
    let onStepCommand: (Int) -> Void
    let onTypeCommand: (Int) -> Void

    // Steps — bound straight through to the nested `RoutineStepsControls`.
    @Binding var stepsExpanded: Bool
    @Binding var warmupSteps: Int
    @Binding var reachSteps: Int
    @Binding var backoffSteps: Int
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
                                     warmupStepBPM: warmupStepBPM, reach: reach,
                                     hasReach: hasReach, tint: tint, onChange: onToggle)
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
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Reach").font(.futura(.subheadline)).foregroundStyle(PocketColor.textPrimary)
                    Text("auto · +\(reach - command) BPM")
                        .font(.futura(.caption2)).foregroundStyle(PocketColor.textSecondary)
                }
                Spacer()
                Text("\(reach) BPM")
                    .font(.pocketMono(.body))
                    .foregroundStyle(tint)
                    .contentTransition(.numericText())
            }
        }
    }
}
