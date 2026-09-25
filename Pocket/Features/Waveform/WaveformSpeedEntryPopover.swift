import SwiftUI

// The speed bar's numeric entry (ADR 0124), split out of `WaveformSpeedBar.swift` to keep that file
// under the line budget when the walkthrough's click hint (ADR 0220 D4) joined the metronome control.

/// Type an exact playback speed (ADR 0124). Out-of-range is **named, not clamped**: silently
/// accepting 1.5 for a typed 2 would look like the field ate the keystrokes, so the rejection is
/// spelled out and the value stands until it's valid. Parsing lives in `TempoMath.parse(speedEntry:)`.
struct SpeedEntryPopover: View {
    @Binding var speed: Double
    let onUserAdjust: () -> Void
    let onDone: () -> Void

    @State private var text = ""
    @State private var error: String?
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Playback speed")
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            HStack(spacing: 6) {
                TextField("1.00", text: $text)
                    .font(.pocketMono(.title3))
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .focused($focused)
                    .submitLabel(.done)
                    .onSubmit(commit)
                    .frame(width: 110)
                Text("×")
                    .font(.pocketMono(.title3))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            Text(error ?? rangeHint)
                .font(.futura(.caption))
                .foregroundStyle(error == nil ? PocketColor.textSecondary : PocketColor.danger)
                .fixedSize(horizontal: false, vertical: true)
            Button(action: commit) {
                Text("Set")
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(PocketColor.background)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(PocketColor.waveformAccent))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(width: 230)
        .onAppear {
            text = String(format: "%.2f", speed)
            focused = true
        }
    }

    private var rangeHint: String {
        String(format: "Between %.2f× and %.2f×", TempoMath.minSpeed, TempoMath.maxSpeed)
    }

    private func commit() {
        switch TempoMath.parse(speedEntry: text) {
        case .valid(let value):
            onUserAdjust()          // a typed speed is manual control too — stand the automator down
            speed = value
            haptic(.light)
            onDone()
        case .notANumber:
            error = "Enter a number, like 0.75"
        case .outOfRange:
            error = rangeHint
        }
    }
}
