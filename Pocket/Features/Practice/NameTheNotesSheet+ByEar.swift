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
        return VStack(alignment: .leading, spacing: 8) {
            if onTheNeck, let reading {
                let name = Text(spelling.name(pitchClass: reading.root)).bold().foregroundStyle(PocketColor.practice)
                Text("Read from the neck: \(name)")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            pickerLabel("What did you hear?")
            LazyVGrid(columns: sixColumns, spacing: 6) {
                ForEach(0..<12, id: \.self) { pitchClass in
                    pickButton(spelling.name(pitchClass: pitchClass),
                               state: reading?.root != pitchClass ? .plain : onTheNeck ? .read : .picked) {
                        apply(EarPick.name(pitchClass, as: activeKind, over: current, openMidi: tuning.openMidi))
                    }
                }
            }
            // One note and Two notes hold a button each, so they share a row.
            HStack(alignment: .top, spacing: 16) {
                ForEach(EarKind.groups.prefix(2), id: \.title) { kindRow($0, reading: reading, onTheNeck: onTheNeck) }
            }
            .padding(.top, 6)
            ForEach(EarKind.groups.dropFirst(2), id: \.title) { group in
                kindRow(group, reading: reading, onTheNeck: onTheNeck)
                    .padding(.top, 6)
            }
        }
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
                        apply(EarPick.kind(kind, over: labels[active], openMidi: tuning.openMidi))
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

    /// Carry out a By ear tap: save (and maybe move on), or ask before overwriting neck work.
    private func apply(_ pick: EarPick) {
        replacing = nil
        switch pick {
        case .save(let label, let advance):
            labels[active] = label
            if advance { self.advance() }
        case .askToReplace(let label):
            replacing = label
        case .none:
            break
        }
    }
}
