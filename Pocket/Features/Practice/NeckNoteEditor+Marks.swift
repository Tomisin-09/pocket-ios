import SwiftUI

// The five playing marks (ADR 0227 D5), under the neck. A bend changes the note and vibrato colours it, so
// both live on the note, and once there's a bend, *Pre-bend* and *Release* say how it moves (ADR 0288); hammer-on, pull-off and slide are *Into it* (`+Into`): a join from the tap before,
// or a lead-in inside the note when the two were heard as one. Split out for file length; Name the notes
// and the tab writer both draw them (ADR 0235 D9).
extension NeckNoteEditor {

    var marksControls: some View {
        let note = ringedNote
        return VStack(alignment: .leading, spacing: 8) {
            if let placedNote { markedLine(placedNote) }
            intoControls
            // Vibrato sits beside the bends when the row has room for both, and under them when it doesn't.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    bendRow(note)
                    Spacer(minLength: 0)
                    vibratoButton(note)
                }
                VStack(alignment: .leading, spacing: 8) {
                    bendRow(note)
                    vibratoButton(note)
                        .padding(.leading, 52)
                }
            }
            if let note, note.bend > 0 { bendShapeRow(note) }
        }
    }

    private func bendRow(_ note: FrettedNote?) -> some View {
        HStack(spacing: 8) {
            rowTitle("Bend").fixedSize().frame(minWidth: 44, alignment: .leading)
            MarkSegments(options: FrettedNote.bends.map { bend in
                .init(title: Self.bendTitle(bend), isOn: note?.bend == bend, isEnabled: note != nil) {
                    mark { $0.changeBend(to: bend) }
                }
            })
        }
    }

    private func vibratoButton(_ note: FrettedNote?) -> some View {
        markToggle("~ Vibrato", isOn: note?.vibrato == true, isEnabled: note != nil) { $0.vibrato.toggle() }
    }

    /// How the bend moves (ADR 0288), under the bend once there is one, lined up with its sizes. Two
    /// switches rather than four choices, because a bend can be both: bent before the pick, then let down.
    private func bendShapeRow(_ note: FrettedNote) -> some View {
        HStack(spacing: 8) {
            markToggle("Pre-bend", isOn: note.preBent, isEnabled: true) { $0.preBent.toggle() }
            markToggle("Release", isOn: note.releases, isEnabled: true) { $0.releases.toggle() }
        }
        .padding(.leading, 52)
    }

    /// A mark that's on or off, filled while it's on.
    private func markToggle(_ title: String, isOn: Bool, isEnabled: Bool,
                            change: @escaping (inout FrettedNote) -> Void) -> some View {
        Button {
            mark(change)
        } label: {
            Text(title)
                .font(.futura(.footnote, weight: isOn ? .bold : nil))
                .padding(.horizontal, 10)
                .frame(minHeight: 32)
                .foregroundStyle(isOn ? PocketColor.background : PocketColor.textPrimary)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isOn ? accent : .clear))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(isOn ? .clear : PocketColor.surfaceBorder))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// What a bend button says: *None*, *½*, *Whole*, *1½* (steps).
    nonisolated static func bendTitle(_ semitones: Int) -> String {
        ["None", "½", "Whole", "1½"][min(max(semitones, 0), 3)]
    }

    /// Which note the marks are on, while the strip has moved past it (ADR 0234 D3): "Note 12 · G7, until
    /// you place 13". Said only then; otherwise the strip's own *Note 12 of 16* says it.
    private func markedLine(_ index: Int) -> some View {
        let placed = Self.fretText(labels[index], openMidi: tuning.openMidi)
        return HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(noun.capitalized) \(index + 1) · \(placed)")
                .font(.futura(.footnote, weight: .bold))
                .monospacedDigit()
            Text("until you place \(active + 1)")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Marks go on \(noun) \(index + 1), \(placed), until you place \(noun) \(active + 1)")
    }

    /// The note bend and vibrato go on: the one note, or a shape's ringed note (0227 D5). After a note is
    /// placed and the strip moves on, that's still the note just placed (ADR 0234 D3).
    private var ringedNote: FrettedNote? { NeckEditing.ringedNote(labels: labels, cursor: cursor) }

    /// Change the marks on the marked note, or on a shape's ringed note.
    private func mark(_ change: (inout FrettedNote) -> Void) {
        let next = NeckEditing.mark(change, labels: labels, cursor: cursor)
        if next != labels { labels = next }
    }
}
