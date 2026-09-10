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
    /// The local profile (ADR 0113 S2), read for the same reason the exercise library reads it: a
    /// drill saved out of the automator should open on the instrument you actually play.
    @Query private var profiles: [Profile]
    @State private var saving = false

    private typealias Mode = StandaloneMetronomeEngine.AutomatorMode

    /// The instrument a drill saved from here picks up (ADR 0116) — the profile's preferred
    /// instrument when declared, else guitar. Mirrors `ExerciseLibraryView`: before this, the seam
    /// passed nothing, so a bass player's breakdown was silently saved as a guitar drill.
    private var defaultInstrument: Instrument {
        profiles.first?.preferredInstrument ?? .guitar
    }

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
        .background(RoundedRectangle(cornerRadius: 14).fill(PocketColor.metronomeCardWash))
        .sheet(isPresented: $saving) {
            // Captures the tempo live at the moment of the tap (the breakdown point), prefilled as
            // the new exercise's command. Funnels through `plan.finalise(in:)` — the same insert
            // Practice's own `+` runs, so creation behaviour added there lands here too rather than
            // needing a second edit in this file (ADR 0046's "single creation path").
            NewExerciseSheet(initialCommand: engine.bpm,
                             initialSignature: engine.timeSignature,
                             fixedTemplate: .basic,
                             defaultInstrument: defaultInstrument) { plan in
                plan.finalise(in: modelContext)
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
            // **"ramp", not bare "Start"** — with the automator on, the screen carried two controls
            // both reading ▶ Start: this one, and the plain click's transport pinned at the bottom.
            // They do different things, and the app already knew it: the `accessibilityLabel` below
            // has always said "Start ramp". The visible label was the only place the distinction was
            // dropped, so a VoiceOver user never had this problem and a sighted user always did.
            Label(engine.automatorRunning ? "Stop ramp" : "Start ramp",
                  systemImage: engine.automatorRunning ? "stop.fill" : "play.fill")
                .font(.futura(.subheadline, weight: .semibold))
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
                .font(.futura(.subheadline))
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
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .frame(maxWidth: .infinity)
        } else if engine.automatorNoLimit {
            VStack(spacing: 4) {
                Text("\(engine.bpm)")
                    .font(.pocketMono(.title))
                    .foregroundStyle(PocketColor.metronome)
                Text("climbing to \(StandaloneMetronomeEngine.bpmRange.upperBound) BPM max")
                    .font(.futura(.caption))
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
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.metronome)
                .frame(width: 36, height: 36)
                .background(Circle().fill(PocketColor.metronomeCircleWash))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Save \(engine.bpm) beats per minute as an exercise in Practice")
    }

    /// Names the feature and houses the compact "save as exercise" bookmark (when armed) so it
    /// doesn't crowd the controls.
    private var header: some View {
        HStack {
            Text("AUTOMATOR")
                .font(.futura(.caption2, weight: .semibold))
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
            // `adjusts:` is what the row's two nudge buttons say aloud. Spoken labels, not screen
            // copy — the sighted reader has the row's own words beside the number, and VoiceOver
            // reaches the button without them (ADR 0213).
            field("Increase by", suffix: "BPM",
                  AutomatorNumberField(value: engine.automatorStepBPM, range: 1...50,
                                       onChange: { engine.setAutomatorStepBPM($0) },
                                       adjusts: "BPM step"))
            // Bars are counted in small numbers; seconds in larger ones — so the range and
            // step differ by unit (the user's note).
            field("Every", suffix: engine.automatorMode == .bars ? "bars" : "secs",
                  AutomatorNumberField(value: engine.automatorIntervalCount,
                                       range: intervalRange, step: intervalStep,
                                       onChange: { engine.setAutomatorIntervalCount($0) },
                                       adjusts: "interval"))
            // Hidden in infinite mode — there's no target to choose, the ramp climbs to the max.
            if !engine.automatorNoLimit {
                field("Up to", suffix: "BPM",
                      AutomatorNumberField(value: engine.automatorCeiling,
                                           range: StandaloneMetronomeEngine.bpmRange, step: 5,
                                           onChange: { engine.setAutomatorCeiling($0) },
                                           adjusts: "target tempo"))
            }
        }
    }

    private var intervalRange: ClosedRange<Int> { engine.automatorMode == .bars ? 1...32 : 5...600 }
    private var intervalStep: Int { engine.automatorMode == .bars ? 1 : 5 }

    /// One labelled row: a word, the number, its unit.
    ///
    /// Takes the **built** `AutomatorNumberField` rather than its four values. Those values are
    /// exactly that view's own properties, so forwarding them one by one made this a six-parameter
    /// function that existed to retype another type's initialiser — which is what SwiftLint's
    /// parameter-count rule is for, and it was right.
    private func field(_ label: String, suffix: String,
                       _ number: AutomatorNumberField) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
            Spacer()
            number
            Text(suffix)
                .font(.futura(.caption))
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

    /// What this field adjusts, named for VoiceOver (ADR 0213) — a bare noun, no article.
    ///
    /// The two nudge buttons' content is an SF Symbol and nothing else, so without this they
    /// announce as "plus" and "minus" — true of every such pair on the screen, and the panel has
    /// three. The visible row already answers it ("Every … bars", "Up to … BPM"); the buttons simply
    /// could not see their own row, which is the whole shape of this defect.
    ///
    /// **Bare, because two call sites need it differently**: the buttons want "Increase the
    /// interval" and the field wants "Interval". A stored phrase with the article baked in would
    /// mean one of them slicing it back off by length, which is a rule about a string's spelling
    /// hiding inside a view.
    var adjusts: String = ""

    @State private var text = ""
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 6) {
            nudge("minus", says: adjusts.isEmpty ? "Decrease" : "Decrease the \(adjusts)") {
                commit(value - step)
            }
            // `TextField("", …)` — an empty placeholder is an empty label, so VoiceOver reaches an
            // editable field with nothing to say about it (ADR 0213). The placeholder stays empty:
            // the number is always present, so a visible placeholder would never be seen, and this
            // is the half only a listener needs.
            TextField("", text: $text)
                .accessibilityLabel(adjusts.isEmpty ? "Value" : adjusts.capitalized)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.pocketMono(.title3))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(width: 54)
                .focused($focused)
                .onChange(of: focused) { _, isFocused in if !isFocused { commit(Int(text) ?? value) } }
                .keyboardDoneButton(tint: PocketColor.metronome)
            nudge("plus", says: adjusts.isEmpty ? "Increase" : "Increase the \(adjusts)") {
                commit(value + step)
            }
        }
        .onAppear { text = "\(value)" }
        .onChange(of: value) { _, newValue in if !focused { text = "\(newValue)" } }
    }

    private func nudge(_ symbol: String, says label: String,
                       action: @escaping () -> Void) -> some View {
        Button { action(); haptic(.light) } label: {
            Image(systemName: symbol)
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(width: 32, height: 32)
                .background(Circle().fill(PocketColor.metronomeCircleWash))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
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
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.metronome)
        }
        .frame(maxWidth: .infinity)
    }
}
