import SwiftUI

/// One **phase row** in Practice Settings (ADR 0221 D1): the phase's title, a line saying what it will
/// play, and — for the three optional phases — its switch on the row itself. Tapping the row opens its
/// controls underneath; the host keeps only one open at a time.
///
/// A switched-off row is dimmed and doesn't open: there is nothing of it in the run to adjust, and its
/// line says what the run does instead. Its tempo survives being off (D2), so switching it back on
/// opens it where it was.
struct PracticePhaseRow<Controls: View>: View {
    let phase: RampPhase
    /// What the phase plays, from `RampSummary.row(_:)`.
    let summary: String
    let isOn: Bool
    let isOpen: Bool
    /// The phase's switch, or `nil` for command, which always plays.
    let isOnBinding: Binding<Bool>?
    let tint: Color
    let onTap: () -> Void
    @ViewBuilder let controls: () -> Controls

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button(action: onTap) { heading }
                    .buttonStyle(.plain)
                    .disabled(!isOn)
                    .accessibilityLabel("\(phase.title), \(summary)")
                    .accessibilityHint(isOn ? (isOpen ? "Close" : "Open to adjust") : "")
                if let isOnBinding {
                    Toggle(phase.title, isOn: isOnBinding)
                        .labelsHidden()
                        .tint(tint)
                }
            }
            if isOpen {
                controls()
                    .padding(.leading, 12)
                    .overlay(alignment: .leading) {
                        Rectangle().fill(tint.opacity(0.35)).frame(width: 2)
                    }
                    .transition(.opacity)
            }
        }
        .padding(.vertical, 10)
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(phase.title)
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(titleColor)
                if isOn {
                    Image(systemName: "chevron.right")
                        .font(.futura(.caption2, weight: .semibold))
                        .foregroundStyle(isOpen ? tint : PocketColor.textSecondary)
                        .rotationEffect(.degrees(isOpen ? 90 : 0))
                }
            }
            Text(summary)
                .font(.futura(.caption2))
                .foregroundStyle(PocketColor.textSecondary.opacity(isOn ? 1 : 0.7))
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var titleColor: Color {
        if !isOn { return PocketColor.textSecondary.opacity(0.7) }
        return isOpen ? tint : PocketColor.textPrimary
    }
}

/// A count inside an open phase row — **Steps**, or a hold (**Each step**, **Hold**) — with the
/// hold-repeat −/+ the tempo rows use. The value is shown in the unit the player counts (`8 bars`,
/// `3 passes`); `onStep` must be a pure clamp, because `StepperButton` owns the haptics.
struct PhaseCountRow: View {
    let label: String
    let caption: String
    let value: Int
    /// A unit after the number — "bars", "passes" — or `nil` for a bare count.
    var unit: String?
    /// VoiceOver names for the two buttons: "Fewer warm-up steps" / "More warm-up steps".
    let decreaseLabel: String
    let increaseLabel: String
    let tint: Color
    let onStep: (Int) -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.futura(.subheadline)).foregroundStyle(PocketColor.textPrimary)
                Text(caption).font(.futura(.caption2)).foregroundStyle(PocketColor.textSecondary)
            }
            Spacer()
            StepperButton(symbol: "minus", label: decreaseLabel, tint: tint) { onStep(-1) }
            // Pinned to the tempo field's 56 so every row's −/+ line up down the panel.
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text("\(value)")
                    .font(.pocketMono(.title3))
                    .foregroundStyle(PocketColor.textPrimary)
                    .contentTransition(.numericText())
                if let unit {
                    Text(unit).font(.futura(.caption2)).foregroundStyle(PocketColor.textSecondary)
                }
            }
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: 56)
            .accessibilityElement(children: .combine)
            StepperButton(symbol: "plus", label: increaseLabel, tint: tint) { onStep(1) }
        }
    }
}
