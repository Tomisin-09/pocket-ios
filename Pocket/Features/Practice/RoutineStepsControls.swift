import SwiftUI

/// The collapsible **step** controls on the Practice run setup (ADR 0046 run-UI): the warm-up /
/// reach / back-up granularity, tucked behind a disclosure header so the setup reads as just the
/// tempos + staircase by default. Expand to shape how many intermediate stops the routine places
/// on the climb to command, the climb to the reach, and the descent into the back-off.
struct RoutineStepsControls: View {
    @Binding var expanded: Bool
    @Binding var warmupSteps: Int
    @Binding var reachSteps: Int
    @Binding var backoffSteps: Int
    /// How many intervals the **command plateau** holds — the consolidation dwell (ADR 0078). Range
    /// and caption are supplied by the host so the unit reads right per type (bars vs loop passes).
    @Binding var dwell: Int
    /// The dwell row's caption, e.g. "≈ 16 bars at command" / "≈ 4 passes at command" — the host
    /// recomputes it from the live dwell + the interval size, so it tracks as the stepper moves.
    let dwellCaption: String
    /// The permitted dwell range (dwell is always ≥ 1 — the command plateau must hold).
    var dwellRange: ClosedRange<Int> = 1...12
    /// The amount each warm-up step adds — for the warm-up caption.
    let warmupStepBPM: Int
    /// The reach value — for the reach caption. `hasReach` gates whether the reach row shows.
    let reach: Int
    let hasReach: Bool
    /// Whether the back-off tail is enabled (user-testing note 6) — gates the "Back-up steps" row,
    /// since intermediate descent stops are meaningless with no descent. Defaults `true` so any
    /// other call site is unchanged.
    var hasBackoff = true
    let tint: Color
    /// The tempo unit shown in the warm-up step caption — "BPM" for an exercise, "%" for a loop
    /// run (whose tempos are percent-of-original, ADR 0046 Phase B). Defaults to "BPM" so the
    /// exercise call site is unchanged.
    var stepUnit = "BPM"
    /// Fired on the disclosure toggle so the host can play a haptic. The ± step buttons feed their
    /// own hold-repeat haptics via `StepperButton`, so they no longer route through here.
    let onChange: () -> Void

    private static let range = 0...6

    var body: some View {
        VStack(spacing: 14) {
            header
            if expanded { rows }
        }
    }

    private var header: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            onChange()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Steps").font(.futura(.subheadline)).foregroundStyle(PocketColor.textPrimary)
                    Text(summary).font(.futura(.caption2)).foregroundStyle(PocketColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(PocketColor.textSecondary)
                    .rotationEffect(.degrees(expanded ? 90 : 0))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Steps, \(summary)")
        .accessibilityHint(expanded ? "Collapse" : "Expand to adjust")
    }

    private var rows: some View {
        VStack(spacing: 14) {
            stepRow(label: "Warm-up steps", value: $warmupSteps,
                    caption: warmupSteps == 0 ? "straight to command" : "+\(warmupStepBPM) \(stepUnit) per step")
            if hasReach {
                stepRow(label: "Reach steps", value: $reachSteps,
                        caption: reachSteps == 0 ? "jump straight to reach" : "ease up to \(reach)")
            }
            if hasBackoff {
                stepRow(label: "Back-up steps", value: $backoffSteps,
                        caption: backoffSteps == 0 ? "drop straight to back-off" : "ease back down")
            }
            stepRow(label: "Command", value: $dwell, caption: dwellCaption, range: dwellRange)
        }
    }

    /// One-line digest of the counts for the collapsed header.
    private var summary: String {
        var parts = ["\(warmupSteps) warm-up"]
        if hasReach { parts.append("\(reachSteps) reach") }
        if hasBackoff { parts.append("\(backoffSteps) back-up") }
        parts.append("\(dwell) command")
        return parts.joined(separator: " · ")
    }

    private func stepRow(label: String, value: Binding<Int>, caption: String,
                         range: ClosedRange<Int> = Self.range) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.futura(.subheadline)).foregroundStyle(PocketColor.textPrimary)
                Text(caption).font(.futura(.caption2)).foregroundStyle(PocketColor.textSecondary)
            }
            Spacer()
            StepperButton(symbol: "minus", label: "Fewer \(label)", tint: tint) {
                adjust(value, by: -1, in: range)
            }
            Text("\(value.wrappedValue)")
                .font(.pocketMono(.title3))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(width: 56)
                .contentTransition(.numericText())
            StepperButton(symbol: "plus", label: "More \(label)", tint: tint) {
                adjust(value, by: 1, in: range)
            }
        }
    }

    /// Pure clamp — `StepperButton` owns the ±/hold-repeat haptics, so this must not call `onChange`
    /// (the disclosure toggle still does). The bindings drive the host's dirty tracking directly.
    private func adjust(_ value: Binding<Int>, by delta: Int, in range: ClosedRange<Int>) {
        value.wrappedValue = min(range.upperBound, max(range.lowerBound, value.wrappedValue + delta))
    }
}
