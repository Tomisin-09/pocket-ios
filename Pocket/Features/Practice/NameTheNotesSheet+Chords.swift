import SwiftUI

// **Chords on the neck** (ADR 0227 D4): the *Chords* switch, which turns a tap from "replace the note"
// into "one note per string", the rule the My chords placer already uses, so a double-stop, a triad and a
// six-string chord are the same gesture. Split out for file length.
extension NameTheNotesSheet {

    var chordsControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            // The ⓘ sits beside the switch, never in its label (`InfoPopoverButton`).
            HStack(spacing: 2) {
                rowTitle("Chords")
                InfoPopoverButton(subject: "Chords", info: NamingInfo.chords)
                    .padding(.vertical, -8)
                Spacer(minLength: 8)
                Toggle("Chords", isOn: $cursor.chordsOn)
                    .labelsHidden()
                    .tint(PocketColor.practice)
            }
            if chordsOn {
                Text("Tap other strings to build a chord, one note per string, as in My chords. Tap a note "
                     + "twice to take it out. Bend and vibrato go on the ringed note.")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
