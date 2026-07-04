import SwiftUI

/// A tempo control on the Practice run setup (ADR 0046 run-UI): the −/+ steppers flanking a
/// **typable** BPM readout. The steppers give a quick ±1 nudge and **auto-repeat when held**
/// (`StepperButton`); tapping the number focuses it for keyboard entry, so a big jump can also be
/// typed directly. The typed value is committed and clamped when focus leaves — via the keyboard's
/// **Done** or an interactive scroll-to-dismiss — and the field always snaps back to the clamped
/// value. `onStep` must be a pure clamp: `StepperButton` owns the hold-repeat haptics.
struct EditableTempoRow: View {
    let label: String
    let caption: String
    let value: Int
    let tint: Color
    /// ±1 nudge with the caller's clamp + haptic (the existing stepper behaviour).
    let onStep: (Int) -> Void
    /// Commit a typed value — the caller clamps into range (working ≤ command ≤ bounds).
    let onType: (Int) -> Void

    @State private var draft = ""
    @FocusState private var typing: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.futura(.subheadline)).foregroundStyle(PocketColor.textPrimary)
                Text(caption).font(.futura(.caption2)).foregroundStyle(PocketColor.textSecondary)
            }
            Spacer()
            StepperButton(symbol: "minus", label: "Lower \(label)", tint: tint) { onStep(-1) }
            TextField("", text: $draft)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.pocketMono(.title3))
                .foregroundStyle(PocketColor.textPrimary)
                // Fixed width (not minWidth): a TextField is greedy and would otherwise stretch,
                // pushing the −/+ apart. Pinned so the cluster matches the step rows' `Text`.
                .frame(width: 56)
                .focused($typing)
                .accessibilityLabel("\(label) tempo")
                .accessibilityValue("\(value)")
            StepperButton(symbol: "plus", label: "Raise \(label)", tint: tint) { onStep(1) }
        }
        .onAppear { draft = "\(value)" }
        // Keep the field in sync when the value moves from elsewhere (a stepper on the *other*
        // row clamping this one, the promote button), but never while the user is mid-type.
        .onChange(of: value) { _, updated in if !typing { draft = "\(updated)" } }
        .onChange(of: typing) { _, isTyping in
            if isTyping { draft = "\(value)" } else { commit() }
        }
        .toolbar {
            if typing {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { typing = false }
                }
            }
        }
    }

    /// Parse and hand the typed value up for clamping; then resync to the committed value so an
    /// out-of-range or empty entry visibly snaps to what was actually stored.
    private func commit() {
        if let typed = Int(draft) { onType(typed) }
        draft = "\(value)"
    }
}
