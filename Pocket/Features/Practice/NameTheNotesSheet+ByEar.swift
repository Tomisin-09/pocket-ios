import SwiftUI

// **By ear** (ADR 0227 D6, D7): what you heard, with no position. A note name, or a root and a quality,
// from one grid of names and the kinds grouped by how many notes they hold. The kind stays selected and
// a name saves and moves on, so a solo named by ear is one tap a note. Split out for file length.
extension NameTheNotesSheet {

    var earPicker: some View {
        let current = labels[active]
        // What the answer says here: named on this sheet (filled), or read off the neck (outlined).
        let reading = current?.earReading(openMidi: tuning.openMidi)
        let onTheNeck = current?.isOnTheNeck ?? false
        let shape = NeckShape.read(current?.frettedNotes ?? [], openMidi: tuning.openMidi)
        // A shape that spells no chord still has notes: they're outlined, loose, rather than nothing.
        let loose = shape?.chord == nil ? shape?.pitchClasses ?? [] : []
        return VStack(alignment: .leading, spacing: 8) {
            if onTheNeck, let line = readLine(current, reading: reading, shape: shape) {
                line
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // ↶ ↷ on the right, in the same spot as on Fret & string (0252 D3).
            HStack(spacing: 8) {
                pickerLabel("What did you hear?")
                Spacer(minLength: 8)
                historyButtons
            }
            LazyVGrid(columns: sixColumns, spacing: 6) {
                ForEach(0..<12, id: \.self) { pitchClass in
                    let isRead = reading?.root == pitchClass || loose.contains(pitchClass)
                    pickButton(spelling.name(pitchClass: pitchClass),
                               state: !isRead ? .plain : onTheNeck ? .read : .picked) {
                        apply(EarPick.name(pitchClass, as: activeKind, over: current, openMidi: tuning.openMidi),
                              advancesOnReplace: true)
                    }
                }
            }
            // One note and Two notes hold a button each, so they share a row.
            HStack(alignment: .top, spacing: 16) {
                ForEach(EarKind.groups.prefix(2), id: \.title) { kindRow($0, reading: reading, onTheNeck: onTheNeck) }
            }
            .padding(.top, 6)
            Text("Any other double-stop is named on the neck, by its interval.")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
            ForEach(EarKind.groups.dropFirst(2), id: \.title) { group in
                kindRow(group, reading: reading, onTheNeck: onTheNeck)
                    .padding(.top, 6)
            }
        }
    }

    /// What the neck's answer reads as here (0227 D7): the note it sounds, the chord a shape spells, or,
    /// for a shape that spells none, its interval and notes.
    private func readLine(_ current: PieceLabel?, reading: EarReading?, shape: ShapeReading?) -> Text? {
        let tint = PocketColor.practice
        guard let shape else {
            guard let reading else { return nil }
            let name = Text(spelling.name(pitchClass: reading.root)).bold().foregroundStyle(tint)
            return Text("Read from the neck: \(name)\(bentFrom(current))")
        }
        let name = Text(shape.name(spelling: spelling)).bold().foregroundStyle(tint)
        if shape.chord != nil { return Text("Read from your \(shape.word.lowercased()) on the neck: \(name)") }
        let names = shape.pitchClasses.map { spelling.name(pitchClass: $0) }
        let notes = names.count > 1 ? names.dropLast().joined(separator: ", ") + " and " + names[names.count - 1]
            : names.joined()
        return Text("Read from the neck: a \(shape.word.lowercased()), \(name) (\(notes))")
    }

    /// ", G7 bent a whole step" when the placed note is bent, so the read name isn't a surprise.
    private func bentFrom(_ label: PieceLabel?) -> String {
        guard let note = label?.singleNote, note.bend > 0 else { return "" }
        let size = ["", "a half step", "a whole step", "a step and a half"][min(note.bend, 3)]
        return ", \(fretText([FrettedNote(string: note.string, fret: note.fret)])) bent \(size)"
    }

    /// The kind a name saves as: the current answer's own when it was named by ear, else the one left
    /// selected. What's lit is always what a name tap will save.
    private var activeKind: EarKind {
        labels[active].flatMap(EarKind.init(namedAs:)) ?? earKind
    }

    /// A group's title over its kinds. The long group scrolls sideways; the others fit as they are.
    private func kindRow(_ group: EarKind.Group, reading: EarReading?, onTheNeck: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            pickerLabel(group.title)
            let buttons = HStack(spacing: 6) {
                ForEach(group.kinds, id: \.self) { kind in
                    pickButton(kind.title, state: kindState(kind, reading: reading, onTheNeck: onTheNeck)) {
                        earKind = kind
                        apply(EarPick.kind(kind, over: labels[active], openMidi: tuning.openMidi),
                              advancesOnReplace: false)
                    }
                    .frame(minWidth: 52)
                }
            }
            if group.kinds.count > 6 {
                ScrollView(.horizontal, showsIndicators: false) { buttons }
            } else {
                buttons.fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    /// The kind a name will save as is filled. What the neck reads is outlined when it's something else.
    private func kindState(_ kind: EarKind, reading: EarReading?, onTheNeck: Bool) -> PickState {
        if kind == activeKind { return .picked }
        return onTheNeck && reading?.kind == kind ? .read : .plain
    }

    /// Carry out a By ear tap: save (and maybe move on), or ask before overwriting neck work. A name that
    /// had to ask still moves on once replaced, as it would have without asking.
    private func apply(_ pick: EarPick, advancesOnReplace: Bool) {
        replacing = nil
        switch pick {
        case .save(let label, let advance):
            labels[active] = label
            if advance { self.advance() }
        case .askToReplace(let label):
            replacing = label
            replacingAdvances = advancesOnReplace
        case .none:
            break
        }
    }
}
