import SwiftUI

/// The Metronome screen's hero BPM readout, **typed into directly**: tap the number, a number pad
/// opens, and the value commits when focus leaves — the keyboard's checkmark
/// (`KeyboardDismissAccessory`), a scroll, or a tap elsewhere. The screen's other three ways in (±1, the slider, TAP) all move by feel; getting
/// to 138 from 96 took either 42 taps or a slider you can't land a specific number on.
///
/// Same contract as `EditableTempoRow` and `AutomatorNumberField`, the two typable tempo fields
/// already shipped: a *draft* string that the live value only refreshes while the field is **not**
/// focused (so a ramp climbing underneath can't rewrite what is half-typed), and a commit that hands
/// the parsed value to the clamp and then resyncs — so `999`, `0` or an empty field visibly snap
/// back to what was actually stored rather than sitting there as a number the engine never took.
///
/// **Tapping it empties it**, and the tempo it held shows greyed as the placeholder until you type.
/// Before, the draft kept the old digits and the caret landed wherever the tap fell — often the
/// start, `|90` — so typing 120 made 12090, which the clamp turned into 300. Emptied, what you type is
/// the tempo; dismiss without typing and the empty draft commits nothing and resyncs.
///
/// Its own view because it owns focus state: kept inline, every keystroke would re-render the
/// controls around it. It also costs the readout `.contentTransition(.numericText())` — a
/// `TextField` has no such transition — which is the one thing typing takes away here.
struct TypableTempo: View {
    let engine: StandaloneMetronomeEngine

    @State private var draft = ""
    @FocusState private var typing: Bool

    var body: some View {
        TextField("", text: $draft, prompt: Text("\(engine.bpm)"))
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.pocketMono(.largeTitle))
            .foregroundStyle(PocketColor.textPrimary)
            // Fixed width, not intrinsic: a TextField is greedy and would push the steppers to the
            // screen edges, and a width that tracked the digit count would make the whole readout
            // jump as the tempo crossed 99.
            .frame(width: 132)
            .focused($typing)
            .accessibilityLabel("Tempo in beats per minute")
            .accessibilityValue("\(engine.bpm)")
            .onAppear { draft = "\(engine.bpm)" }
            .onChange(of: engine.bpm) { _, updated in if !typing { draft = "\(updated)" } }
            .onChange(of: typing) { _, isTyping in
                if isTyping { draft = "" } else { commit() }
            }
    }

    /// Hand the typed value to the engine — which clamps to `bpmRange` and re-bases an armed
    /// automator exactly as a stepper or the slider does — then resync the draft to whatever was
    /// actually stored.
    private func commit() {
        if let typed = Int(draft) { engine.setBPM(typed) }
        draft = "\(engine.bpm)"
    }
}
