import SwiftUI

/// **Another key** in Active listening (ADR 0305 D3): the tempo and the key side by side under the play
/// button, in the same −/+ shape, and under both one line that says the key you're hearing, with
/// *Original key* while you're off it. The shape is the approved mockup's
/// (`https://claude.ai/artifact/XGN3XZoBnL1WVhRdr8Suq9`, *Active listening*).
///
/// The shift lives on the `ContinuousLoopPlayer`, so it starts at 0 every visit and is never saved.
struct LoopTempoAndKeyControls: View {
    let player: ContinuousLoopPlayer
    /// The recording's key, which the line moves from. `.unknown` when the song has none: the line then
    /// says how far it moved.
    let recordingKey: MusicalKey

    var body: some View {
        let heard = HeardKey(recording: recordingKey, shift: player.keyShift, song: player.songShift)
        VStack(spacing: 10) {
            HStack(spacing: 16) {
                LoopTempoControl(player: player, spacing: 10, valueWidth: 58)
                Rectangle()
                    .fill(PocketColor.surfaceBorder)
                    .frame(width: 1, height: 40)
                    .accessibilityHidden(true)
                LoopKeyControl(player: player)
            }
            HStack(spacing: 10) {
                Text(heard.line)
                    .font(.futura(.subheadline))
                    .foregroundStyle(heard.isShifted ? PocketColor.textPrimary : PocketColor.textSecondary)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("listening.key.line")
                if heard.isShifted {
                    Button("Original key") {
                        haptic(.light)
                        player.setKeyShift(0)
                    }
                    .font(.futura(.subheadline, weight: .medium))
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.capsule)
                    .controlSize(.small)
                    .tint(PocketColor.practice)
                    .accessibilityIdentifier("listening.key.original")
                }
            }
            .frame(minHeight: 30)
            .animation(.easeInOut(duration: 0.15), value: heard.isShifted)
        }
    }
}

/// The **−/+ key stepper**: whole semitones, six either way (ADR 0305 D2), live while sounding. Drawn like
/// `LoopTempoControl` beside it, so the two read as one row of the same kind of control.
struct LoopKeyControl: View {
    let player: ContinuousLoopPlayer
    var buttonSize: CGFloat = 32

    var body: some View {
        HStack(spacing: 10) {
            keyButton(symbol: "minus.circle.fill", delta: -1, enabled: player.canShiftDown,
                      label: "Down a semitone")
            VStack(spacing: 0) {
                Text(KeyShift.stepperValue(player.keyShift))
                    .font(.pocketMono(.title3))
                    .foregroundStyle(PocketColor.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("key")
                    .font(.futura(.caption2))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .frame(minWidth: 46)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityValue)
            .accessibilityIdentifier("listening.key.value")
            keyButton(symbol: "plus.circle.fill", delta: 1, enabled: player.canShiftUp, label: "Up a semitone")
        }
        .disabled(player.isUnavailable)
    }

    private var accessibilityValue: String {
        let shift = player.keyShift
        guard shift != 0 else { return player.songShift == 0 ? "Key, as recorded" : "Key, as the song plays" }
        return "Key, \(abs(shift)) semitone\(abs(shift) == 1 ? "" : "s") \(shift > 0 ? "up" : "down")"
    }

    private func keyButton(symbol: String, delta: Int, enabled: Bool, label: String) -> some View {
        Button {
            haptic(.light)
            player.setKeyShift(player.keyShift + delta)
        } label: {
            Image(systemName: symbol)
                .font(.system(size: buttonSize))
                .foregroundStyle(enabled ? PocketColor.practice : PocketColor.surfaceBorder)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }
}
