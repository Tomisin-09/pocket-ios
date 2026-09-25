import SwiftUI

/// One tempo control in the phase rows — its value and the host's clamped edits. `onReset` is set only
/// while the value is a pin, which is what reads it as custom and offers **Reset to auto**.
struct PhaseTempoControl {
    let value: Int
    let onStep: (Int) -> Void
    let onType: (Int) -> Void
    var onReset: (() -> Void)?
}

/// The collapsible **Practice Settings** panel on an exercise's run setup and its routine-block preview
/// (V1 feedback), organised **by phase** (ADR 0221 D1): four rows — Warm-up, Command, Reach, Back off —
/// in the order the run plays them. Each row says what its phase will play; the optional three carry
/// their switch on the row; tapping a row opens its tempo, steps and hold underneath, one row at a
/// time. The host lights the open phase's bars in the staircase from `openPhase`.
///
/// It replaced a list of tempos above a nested Steps panel, which split every phase across two
/// disclosures and showed command twice, meaning two things.
///
/// A pure presentation shell: the tempos route back through the host's clamp closures, and the shape
/// is a binding, so edits land wherever the host keeps them — local until Start or Save on the run
/// screen (ADR 0057), written straight to the model on the block preview.
struct PracticeSettingsPanel: View {
    @Binding var expanded: Bool
    /// The one open row, or `nil`.
    @Binding var openPhase: RampPhase?
    @Binding var shape: RunShape
    /// **Start at** — the warm-up floor (`workingTempo`, ADR 0221 D5).
    let startAt: PhaseTempoControl
    let command: PhaseTempoControl
    let reach: PhaseTempoControl
    /// **Settle at** — the back off's floor.
    let settleAt: PhaseTempoControl
    /// The command hold the run will actually play, when a session has fitted it to a block (ADR 0129).
    var playedDwell: Int?
    var tempoUnit: TempoUnit = .bpm
    var holdUnit: RunLength.Unit = .bars
    var unitsPerInterval = StandaloneMetronomeEngine.automatorDefaultBars
    let tint: Color
    /// Fired on the disclosure and the row taps so the host plays a haptic.
    let onToggle: () -> Void

    private var tempos: RampTempos {
        RampTempos(working: startAt.value, command: command.value, reach: reach.value,
                   backoff: settleAt.value)
    }

    private var summary: RampSummary {
        RampSummary(tempos: tempos, shape: shape, reachIsAuto: reach.onReset == nil,
                    backoffIsAuto: settleAt.onReset == nil, tempoUnit: tempoUnit,
                    holdUnit: holdUnit, unitsPerInterval: unitsPerInterval)
    }

    var body: some View {
        VStack(spacing: 14) {
            header
            if expanded { rows }
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
                    Text(summary.header)
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
        .accessibilityLabel("Practice settings, \(summary.header)")
        .accessibilityHint(expanded ? "Collapse" : "Expand to shape each phase of the run")
    }

    private var rows: some View {
        VStack(spacing: 0) {
            ForEach(RampPhase.allCases) { phase in
                Rectangle().fill(PocketColor.surfaceBorder).frame(height: 1)
                PracticePhaseRow(phase: phase, summary: summary.row(phase), isOn: shape.isOn(phase),
                                 isOpen: shape.isOn(phase) && openPhase == phase,
                                 isOnBinding: phase.isOptional ? switchBinding(phase) : nil,
                                 tint: tint, onTap: { toggleOpen(phase) },
                                 controls: { controls(for: phase) })
            }
            Rectangle().fill(PocketColor.surfaceBorder).frame(height: 1)
        }
    }

    // MARK: - An open row's controls (D3)

    @ViewBuilder
    private func controls(for phase: RampPhase) -> some View {
        VStack(spacing: 14) {
            switch phase {
            case .warmup:
                tempoRow("Start at", control: startAt, phase: phase)
                stepsRow(phase)
                holdRow(phase, label: "Each step")
            case .command:
                tempoRow("Tempo", control: command, phase: phase, spokenName: "Command")
                holdRow(phase, label: "Hold")
            case .reach:
                tempoRow("Tempo", control: reach, phase: phase, spokenName: "Reach")
                resetButton(reach, hint: "Clear the custom reach; use the auto-derived goal")
                stepsRow(phase)
                holdRow(phase, label: "Each step")
            case .backoff:
                tempoRow("Settle at", control: settleAt, phase: phase, spokenName: "Back off")
                resetButton(settleAt, hint: "Clear the custom back off; use the auto-derived floor")
                stepsRow(phase)
                holdRow(phase, label: "Each step")
            }
        }
    }

    private func tempoRow(_ label: String, control: PhaseTempoControl, phase: RampPhase,
                          spokenName: String? = nil) -> some View {
        EditableTempoRow(label: label, caption: summary.pinCaption(phase), value: control.value,
                         tint: tint, onStep: control.onStep, onType: control.onType,
                         accessibilityName: spokenName)
    }

    /// **Steps** — the rungs the phase draws, 1 up to `min(7, gap)` (D4). The value is read back
    /// through the same clamp the ramp uses, so it is always the number of bars drawn.
    private func stepsRow(_ phase: RampPhase) -> some View {
        let name = "\(phase.caption) steps"
        return PhaseCountRow(label: "Steps", caption: summary.stepsCaption(phase),
                             value: tempos.rungs(of: phase, in: shape),
                             decreaseLabel: "Fewer \(name)", increaseLabel: "More \(name)",
                             tint: tint) { delta in
            let next = tempos.rungs(of: phase, in: shape) + delta
            shape.setRungs(phase, min(tempos.maxRungs(of: phase, in: shape), max(1, next)))
        }
    }

    /// A hold, shown in bars or passes and stepped by one interval (D3).
    private func holdRow(_ phase: RampPhase, label: String) -> some View {
        let count = shape.hold(phase) * max(1, unitsPerInterval)
        let name = "\(phase.caption) hold"
        return PhaseCountRow(label: label, caption: summary.holdCaption(phase, playedDwell: playedDwell),
                             value: count, unit: holdUnit.noun(count),
                             decreaseLabel: "Shorter \(name)", increaseLabel: "Longer \(name)",
                             tint: tint) { delta in
            shape.setHold(phase, shape.hold(phase) + delta)
        }
    }

    @ViewBuilder
    private func resetButton(_ control: PhaseTempoControl, hint: String) -> some View {
        if let onReset = control.onReset {
            Button(action: onReset) {
                Label("Reset to auto", systemImage: "arrow.uturn.backward")
                    .font(.futura(.caption)).foregroundStyle(tint)
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .accessibilityHint(hint)
        }
    }

    // MARK: - Rows opening and switching

    private func toggleOpen(_ phase: RampPhase) {
        withAnimation(.easeInOut(duration: 0.2)) { openPhase = openPhase == phase ? nil : phase }
        onToggle()
    }

    /// A phase's switch. Switching one on opens it, so the controls that just came back are in view;
    /// switching the open one off closes it. Its tempo is untouched either way (D2).
    private func switchBinding(_ phase: RampPhase) -> Binding<Bool> {
        Binding(get: { shape.isOn(phase) }, set: { isOn in
            withAnimation(.easeInOut(duration: 0.2)) {
                shape.setOn(phase, isOn)
                if isOn {
                    openPhase = phase
                } else if openPhase == phase {
                    openPhase = nil
                }
            }
        })
    }
}
