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
    /// The BPM each warm-up step adds — for the warm-up caption.
    let warmupStepBPM: Int
    /// The reach BPM — for the reach caption. `hasReach` gates whether the reach row shows.
    let reach: Int
    let hasReach: Bool
    let tint: Color
    /// Fired on every change/toggle so the host can play a haptic.
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
                    Text("Steps").font(.subheadline).foregroundStyle(PocketColor.textPrimary)
                    Text(summary).font(.caption2).foregroundStyle(PocketColor.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
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
                    caption: warmupSteps == 0 ? "straight to command" : "+\(warmupStepBPM) BPM per step")
            if hasReach {
                stepRow(label: "Reach steps", value: $reachSteps,
                        caption: reachSteps == 0 ? "jump straight to reach" : "ease up to \(reach)")
            }
            stepRow(label: "Back-up steps", value: $backoffSteps,
                    caption: backoffSteps == 0 ? "drop straight to back-off" : "ease back down")
        }
    }

    /// One-line digest of the counts for the collapsed header.
    private var summary: String {
        var parts = ["\(warmupSteps) warm-up"]
        if hasReach { parts.append("\(reachSteps) reach") }
        parts.append("\(backoffSteps) back-up")
        return parts.joined(separator: " · ")
    }

    private func stepRow(label: String, value: Binding<Int>, caption: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.subheadline).foregroundStyle(PocketColor.textPrimary)
                Text(caption).font(.caption2).foregroundStyle(PocketColor.textSecondary)
            }
            Spacer()
            stepButton(symbol: "minus", label: "Fewer \(label)") { adjust(value, by: -1) }
            Text("\(value.wrappedValue)")
                .font(.pocketMono(.title3))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(width: 56)
                .contentTransition(.numericText())
            stepButton(symbol: "plus", label: "More \(label)") { adjust(value, by: 1) }
        }
    }

    private func adjust(_ value: Binding<Int>, by delta: Int) {
        value.wrappedValue = min(Self.range.upperBound,
                                 max(Self.range.lowerBound, value.wrappedValue + delta))
        onChange()
    }

    private func stepButton(symbol: String, label: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(width: 38, height: 38)
                .background(Circle().fill(tint.opacity(0.18)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
