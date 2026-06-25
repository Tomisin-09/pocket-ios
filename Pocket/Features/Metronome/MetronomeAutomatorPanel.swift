import SwiftUI

/// The inline tempo-automator panel on the standalone metronome screen (ADR 0043, slice 4),
/// modelled on Tempo's automator: a single **Off / By Bars / By Time** segmented control,
/// then tap-to-type (validated) fields for the increase, interval, and ceiling, and the
/// **ramp staircase** as a live progress tracker. The floor is always the current metronome
/// tempo (set it on the main controls, then arm); the live ramp runs in the engine.
struct MetronomeAutomatorPanel: View {
    let engine: StandaloneMetronomeEngine

    private typealias Mode = StandaloneMetronomeEngine.AutomatorMode

    var body: some View {
        VStack(spacing: 12) {
            header
            Picker("Automate tempo", selection: Binding(get: { engine.automatorMode },
                                                        set: { engine.setAutomatorMode($0) })) {
                Text("Off").tag(Mode.off)
                Text("By Bars").tag(Mode.bars)
                Text("By Time").tag(Mode.seconds)
            }
            .pickerStyle(.segmented)

            if engine.automatorMode != .off {
                fields
                MetronomeRampTracker(engine: engine)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(PocketColor.metronome.opacity(0.08)))
    }

    /// Names the feature and houses the restart control (when a ramp is armed) so it doesn't
    /// crowd the staircase.
    private var header: some View {
        HStack {
            Text("AUTOMATOR")
                .font(.caption2.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(PocketColor.textSecondary)
            Spacer()
            if engine.automatorMode != .off {
                Button { engine.restartAutomator(); haptic(.light) } label: {
                    Label("Restart", systemImage: "arrow.counterclockwise")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(PocketColor.metronome)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Restart ramp")
            }
        }
    }

    private var fields: some View {
        VStack(spacing: 8) {
            field("Increase by", value: engine.automatorStepBPM, range: 1...50, suffix: "BPM") {
                engine.setAutomatorStepBPM($0)
            }
            // Bars are counted in small numbers; seconds in larger ones — so the range and
            // step differ by unit (the user's note).
            field("Every", value: engine.automatorIntervalCount,
                  range: intervalRange, step: intervalStep,
                  suffix: engine.automatorMode == .bars ? "bars" : "secs") {
                engine.setAutomatorIntervalCount($0)
            }
            field("Up to", value: engine.automatorCeiling,
                  range: StandaloneMetronomeEngine.bpmRange, step: 5, suffix: "BPM") {
                engine.setAutomatorCeiling($0)
            }
        }
    }

    private var intervalRange: ClosedRange<Int> { engine.automatorMode == .bars ? 1...32 : 5...600 }
    private var intervalStep: Int { engine.automatorMode == .bars ? 1 : 5 }

    private func field(_ label: String, value: Int, range: ClosedRange<Int>, step: Int = 1,
                       suffix: String, onChange: @escaping (Int) -> Void) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(PocketColor.textSecondary)
            Spacer()
            AutomatorNumberField(value: value, range: range, step: step, onChange: onChange)
            Text(suffix)
                .font(.caption)
                .foregroundStyle(PocketColor.textSecondary)
                .frame(width: 34, alignment: .leading)
        }
    }
}

/// A validated numeric field: tap the number to type it (number pad, clamped on commit), or
/// nudge with −/+. The keyboard is dismissed by the screen-level **Done** accessory (see
/// `MetronomeView`), which resigns first responder and commits via the focus change.
struct AutomatorNumberField: View {
    let value: Int
    let range: ClosedRange<Int>
    var step: Int = 1
    let onChange: (Int) -> Void

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            nudge("minus") { commit(value - step) }
            TextField("", text: $text)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.pocketMono(.title3))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(width: 54)
                .focused($focused)
                .onChange(of: focused) { _, isFocused in if !isFocused { commit(Int(text) ?? value) } }
            nudge("plus") { commit(value + step) }
        }
        .onAppear { text = "\(value)" }
        .onChange(of: value) { _, newValue in if !focused { text = "\(newValue)" } }
    }

    private func nudge(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button { action(); haptic(.light) } label: {
            Image(systemName: symbol)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(PocketColor.metronome.opacity(0.15)))
        }
        .buttonStyle(.plain)
    }

    private func commit(_ raw: Int) {
        let clamped = min(range.upperBound, max(range.lowerBound, raw))
        text = "\(clamped)"
        focused = false
        onChange(clamped)
    }
}

/// The live ramp staircase — the same `RampStairs` the panel configures, with the **current
/// step lit** as the tempo climbs. The floor / ceiling labels hug the **ends of the ramp**
/// (not the screen edges) and the "Step x/x" sits centred under the bars. A standalone view
/// so the per-step `bpm` updates re-render only this.
private struct MetronomeRampTracker: View {
    let engine: StandaloneMetronomeEngine

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .bottom, spacing: 10) {
                Text("\(engine.automatorStartBPM)")
                    .font(.pocketMono(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                RampStairs(shape: RampShape.between(Double(engine.automatorStartBPM),
                                                    Double(engine.automatorCeiling)),
                           steps: engine.automatorTotalSteps,
                           tint: PocketColor.metronome,
                           currentStep: engine.automatorCurrentStep)
                Text("\(engine.automatorCeiling)")
                    .font(.pocketMono(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Text("Step \(engine.automatorCurrentStep)/\(engine.automatorTotalSteps)")
                .font(.caption)
                .foregroundStyle(PocketColor.metronome)
        }
        .frame(maxWidth: .infinity)
    }
}
