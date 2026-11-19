import SwiftUI

/// **Pitch** in Edit song (ADR 0305 D4): the song raised or lowered to meet your tuning, straight under the
/// key because, like the key, it describes the recording. One *Raise or lower* row with the key it lands
/// in, the value in mono and a stepper, then *Back to the recording*, greyed at 0. The shape is the approved
/// mockup's (`https://claude.ai/artifact/XGN3XZoBnL1WVhRdr8Suq9`, *Edit song*).
///
/// Value-only, like `KeyPickerSection`: it edits a semitone binding and knows nothing about `Song`.
struct SongPitchSection: View {
    @Binding var shift: Int
    /// The recording's key, which the line moves from.
    let key: MusicalKey
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Section {
            // The line runs the row's full width under it: beside the stepper it broke into three lines at
            // the default size. At the accessibility sizes the stepper goes under the name too.
            VStack(alignment: .leading, spacing: 4) {
                let layout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                    : AnyLayout(HStackLayout(spacing: 12))
                layout {
                    Text("Raise or lower")
                        .foregroundStyle(PocketColor.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 12) {
                        Text(KeyShift.stepperValue(shift))
                            .font(.pocketMono(.title3))
                            .foregroundStyle(PocketColor.textPrimary)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .frame(minWidth: 34, alignment: .trailing)
                            .accessibilityHidden(true)
                        Stepper("Raise or lower", value: $shift.animation(.easeInOut(duration: 0.15)),
                                in: -KeyShift.reach...KeyShift.reach)
                            .labelsHidden()
                            .accessibilityValue(KeyShift.songLine(key: key, shift: shift))
                            .accessibilityIdentifier("songEdit.pitch.stepper")
                    }
                }
                Text(KeyShift.songLine(key: key, shift: shift))
                    .font(.futura(.footnote))
                    .foregroundStyle(shift == 0 ? PocketColor.textSecondary : PocketColor.library)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("songEdit.pitch.line")
            }
            Button("Back to the recording") {
                withAnimation(.easeInOut(duration: 0.15)) { shift = 0 }
            }
            .font(.futura(.body))
            .foregroundStyle(PocketColor.textSecondary.opacity(shift == 0 ? 0.45 : 1))
            .disabled(shift == 0)
            .accessibilityIdentifier("songEdit.pitch.reset")
        } header: {
            Text("Pitch")
        } footer: {
            Text("For a record that isn't in your tuning. Tuned a half step down? Raise it 1 and play along "
                 + "in Standard. It plays this way everywhere this song plays.")
                .font(.futura(.caption))
        }
    }
}

/// The song player's mark for a raised or lowered song (ADR 0305 D4), with the song's facts under
/// *slowest 75%*: a teal *+1 semitone* that opens Edit song. A song that sounds a half step off with nothing
/// on screen to say so would look like a bug, so it shows whenever the shift isn't 0.
///
/// A plain shape with a tap, not a `Button`: it sits inside the song strip's hold, and a Button fires its
/// tap on a hold's release too, which would open both sheets.
struct SongShiftChip: View {
    let shift: Int
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: shift > 0 ? "arrow.up" : "arrow.down")
                .font(.system(size: 9, weight: .bold))
            Text(KeyShift.chipLabel(shift))
                .font(.pocketMono(.caption2))
                .lineLimit(1)
        }
        .foregroundStyle(PocketColor.library)
        .padding(.horizontal, 8)
        .frame(height: 22)
        .background(Capsule().fill(PocketColor.library.opacity(0.14)))
        .overlay(Capsule().stroke(PocketColor.library, lineWidth: 1))
        .contentShape(Capsule())
        .onTapGesture {
            haptic(.light)
            onTap()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(KeyShift.spokenSongShift(shift))
        .accessibilityHint("Opens Edit song")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("songPlayer.shiftChip")
    }
}

#Preview("Pitch · raised") {
    @Previewable @State var shift = 1
    Form {
        KeyPickerSection(key: .constant(.fSharpMinor))
        SongPitchSection(shift: $shift, key: .fSharpMinor)
    }
}

#Preview("Chip") {
    VStack(spacing: 12) {
        SongShiftChip(shift: 1) {}
        SongShiftChip(shift: -2) {}
    }
    .padding()
    .background(PocketColor.background)
}
