import SwiftData
import SwiftUI

/// The inline tempo-automator panel on the standalone metronome screen (ADR 0043, slice 4),
/// modelled on Tempo's automator: a single **Off / By Bars / By Time** segmented control,
/// then tap-to-type (validated) fields for the increase, interval, and ceiling, and the
/// **ramp staircase** as a live progress tracker. The floor is always the current metronome
/// tempo (set it on the main controls, then arm); the live ramp runs in the engine.
///
/// The automator's stated job (ADR 0046) is **command-tempo discovery** — ramp until your hands
/// break down, and that tempo *is* your command. The **"Save as exercise"** action is the
/// one-directional seam that realises it: it captures the current (breakdown) tempo and hands it
/// into Practice's create flow, prefilled. The automator *feeds* Practice; it never owns an
/// exercise.
struct MetronomeAutomatorPanel: View {
    let engine: StandaloneMetronomeEngine

    @Environment(\.modelContext) private var modelContext
    @State private var saving = false

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
                noLimitToggle
                progress
                startStopButton
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14).fill(PocketColor.metronome.opacity(0.08)))
        .sheet(isPresented: $saving) {
            // Captures the tempo live at the moment of the tap (the breakdown point), prefilled as
            // the new exercise's command. Funnels through the same `commandAnchored` factory as
            // Practice's own create flow — one creation path (ADR 0046).
            NewExerciseSheet(initialCommand: engine.bpm) { name, command in
                modelContext.insert(Exercise.commandAnchored(name: name, command: command))
            }
        }
    }

    /// The explicit **Start / Stop** for the climb (ADR 0048) — arming the segmented control
    /// only configures the ramp; this runs it. Mirrors the main transport so the automator has
    /// its own run gesture rather than climbing silently the moment you arm it.
    private var startStopButton: some View {
        Button {
            if engine.automatorRunning { engine.stopAutomatorRun() } else { engine.startAutomatorRun() }
            haptic(.medium)
        } label: {
            Label(engine.automatorRunning ? "Stop" : "Start",
                  systemImage: engine.automatorRunning ? "stop.fill" : "play.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(Capsule().fill(PocketColor.metronome))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(engine.automatorRunning ? "Stop ramp" : "Start ramp")
    }

    /// **Infinite** mode (ADR 0048): drop the target and let the ramp climb to the system max.
    /// Hides the "Up to" field when on (there's nothing to choose).
    private var noLimitToggle: some View {
        Toggle(isOn: Binding(get: { engine.automatorNoLimit },
                             set: { engine.setAutomatorNoLimit($0) })) {
            Text("No limit")
                .font(.subheadline)
                .foregroundStyle(PocketColor.textSecondary)
        }
        .tint(PocketColor.metronome)
    }

    /// What sits above the Start button: the live **count-in** number while settling in, a
    /// "climbing to max" readout in infinite mode, or the ramp staircase otherwise.
    @ViewBuilder private var progress: some View {
        if let countdown = engine.automatorCountdown {
            VStack(spacing: 4) {
                Text("\(countdown)")
                    .font(.pocketMono(.largeTitle))
                    .foregroundStyle(PocketColor.metronome)
                Text("Counting in")
                    .font(.caption)
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
        } else if engine.automatorNoLimit {
            VStack(spacing: 4) {
                Text("\(engine.bpm)")
                    .font(.pocketMono(.title))
                    .foregroundStyle(PocketColor.metronome)
                Text("climbing to \(StandaloneMetronomeEngine.bpmRange.upperBound) BPM max")
                    .font(.caption)
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
        } else {
            MetronomeRampTracker(engine: engine)
        }
    }

    /// The discovery → Practice seam, as a compact **bookmark** button in the header (the
    /// user's note: the old full-width capsule became a rounded icon). Captures the live tempo
    /// at the tap — "this is the tempo I broke down at — keep it as a drill".
    private var saveAsExerciseButton: some View {
        Button {
            saving = true
            haptic(.medium)
        } label: {
            Image(systemName: "bookmark.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(PocketColor.metronome)
                .frame(width: 36, height: 36)
                .background(Circle().fill(PocketColor.metronome.opacity(0.15)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Save \(engine.bpm) beats per minute as an exercise in Practice")
    }

    /// Names the feature and houses the compact "save as exercise" bookmark (when armed) so it
    /// doesn't crowd the controls.
    private var header: some View {
        HStack {
            Text("AUTOMATOR")
                .font(.caption2.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(PocketColor.textSecondary)
            Spacer()
            if engine.automatorMode != .off {
                saveAsExerciseButton
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
            // Hidden in infinite mode — there's no target to choose, the ramp climbs to the max.
            if !engine.automatorNoLimit {
                field("Up to", value: engine.automatorCeiling,
                      range: StandaloneMetronomeEngine.bpmRange, step: 5, suffix: "BPM") {
                    engine.setAutomatorCeiling($0)
                }
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
                // One bar per plateau (floor + each step to the ceiling), so the bars match
                // the "Step k/N" count and the lit bar is the current plateau exactly.
                RampStairs(shape: RampShape.between(Double(engine.automatorStartBPM),
                                                    Double(engine.automatorCeiling)),
                           steps: engine.automatorTotalSteps + 1,
                           tint: PocketColor.metronome,
                           currentStep: engine.automatorCurrentStep)
                Text("\(engine.automatorCeiling)")
                    .font(.pocketMono(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            // 1-based plateau count: the floor is the 1st tempo you hold and the ceiling the
            // last, so there are `totalSteps + 1` plateaus (reads "Step 1/8" at the floor, not
            // "Step 0/7").
            Text("Step \(engine.automatorCurrentStep + 1)/\(engine.automatorTotalSteps + 1)")
                .font(.caption)
                .foregroundStyle(PocketColor.metronome)
        }
        .frame(maxWidth: .infinity)
    }
}
