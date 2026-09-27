import SwiftUI

// The three pickers of Name the notes (ADR 0225), split out for file length. Each picking sets the
// active chip's label and sounds it, so the answer is heard as it's given.
extension NameTheNotesSheet {

    @ViewBuilder var picker: some View {
        switch mode {
        case .note: notePicker
        case .fret: fretPicker
        case .chord: chordPicker
        }
    }

    private var sixColumns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 6), count: 6) }

    // MARK: - Note name

    /// The twelve names, C to B, spelled for the song's key where it has one (ADR 0123), else by the
    /// player's preference. No octave: a name is what the ear hears first.
    private var notePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            pickerLabel("What did you hear?")
            LazyVGrid(columns: sixColumns, spacing: 6) {
                ForEach(0..<12, id: \.self) { pitchClass in
                    pickButton(spelling.name(pitchClass: pitchClass),
                               isOn: labels[active]?.pitchClass(openMidi: tuning.openMidi) == pitchClass
                                   && !(labels[active]?.isChord ?? false)) {
                        pick(.pitchClass(pitchClass))
                        advance()
                    }
                }
            }
        }
    }

    // MARK: - Fret & string

    /// Strings from the tuner's instrument and tuning (ADR 0115), thinnest first like the tab, and a fret
    /// from 0 to 22. One note per tap: no chords here, no durations, no bends (0225's stopping point).
    private var fretPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                pickerLabel("String")
                Spacer()
                Text(tuning.label)
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            LazyVGrid(columns: sixColumns, spacing: 6) {
                ForEach(Array(TabLine.stringNames(openMidi: tuning.openMidi).enumerated()), id: \.offset) { item in
                    pickButton(item.element.trimmingCharacters(in: .whitespaces),
                               isOn: currentFret?.string == item.offset) {
                        placeFret(string: item.offset, fret: (currentFret ?? fretDraft).fret)
                    }
                }
            }
            HStack(spacing: 12) {
                pickerLabel("Fret")
                Spacer()
                StepperButton(symbol: "minus", label: "Lower fret", tint: PocketColor.practice) {
                    let base = currentFret ?? fretDraft
                    placeFret(string: base.string, fret: max(0, base.fret - 1))
                }
                Text("\((currentFret ?? fretDraft).fret)")
                    .font(.pocketMono(.title3))
                    .monospacedDigit()
                    .frame(minWidth: 36)
                    .accessibilityLabel("Fret \((currentFret ?? fretDraft).fret)")
                StepperButton(symbol: "plus", label: "Higher fret", tint: PocketColor.practice) {
                    let base = currentFret ?? fretDraft
                    placeFret(string: base.string, fret: min(PieceLabel.maxFret, base.fret + 1))
                }
                Button("Next note") {
                    advance()
                    hearSlice()
                }
                .buttonStyle(.bordered)
                .tint(PocketColor.practice)
                .font(.futura(.subheadline))
            }
        }
    }

    /// The active chip's fret, if it has one.
    private var currentFret: TabLine.Note? {
        guard case .fretted(let string, let fret) = labels[active] else { return nil }
        return TabLine.Note(string: string, fret: fret)
    }

    private func placeFret(string: Int, fret: Int) {
        fretDraft = TabLine.Note(string: string, fret: fret)
        pick(.fretted(string: string, fret: fret))
    }

    // MARK: - Chord

    /// A root and a quality, the way a chord is heard and said ("Am7"), from the chord namer's own
    /// vocabulary (ADR 0093). Not a grip: which shape plays it is the player's business.
    private var chordPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            pickerLabel("Root")
            LazyVGrid(columns: sixColumns, spacing: 6) {
                ForEach(0..<12, id: \.self) { root in
                    pickButton(spelling.name(pitchClass: root), isOn: currentChord?.root == root) {
                        pick(.chord(root: root, suffix: currentChord?.suffix ?? chordSuffixDraft))
                    }
                }
            }
            pickerLabel("Quality")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(PieceLabel.chordQualities, id: \.suffix) { quality in
                        pickButton(quality.suffix.isEmpty ? "maj" : quality.suffix,
                                   isOn: (currentChord?.suffix ?? chordSuffixDraft) == quality.suffix) {
                            chordSuffixDraft = quality.suffix
                            if let root = currentChord?.root {
                                pick(.chord(root: root, suffix: quality.suffix))
                            }
                        }
                        .frame(minWidth: 52)
                    }
                }
            }
            HStack {
                Spacer()
                Button("Next chord") {
                    advance()
                    hearSlice()
                }
                .buttonStyle(.bordered)
                .tint(PocketColor.practice)
                .font(.futura(.subheadline))
            }
        }
    }

    private var currentChord: (root: Int, suffix: String)? {
        guard case .chord(let root, let suffix) = labels[active] else { return nil }
        return (root, suffix)
    }

    // MARK: - Shared

    private func pick(_ label: PieceLabel) {
        labels[active] = label
        soundLabel(label)
    }

    private func pickerLabel(_ text: String) -> some View {
        Text(text)
            .font(.futura(.caption))
            .foregroundStyle(PocketColor.textSecondary)
    }

    private func pickButton(_ title: String, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.futura(.subheadline, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 40)
                .padding(.horizontal, 4)
                .foregroundStyle(isOn ? PocketColor.background : PocketColor.textPrimary)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isOn ? PocketColor.textPrimary : PocketColor.surfaceSubtle))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(isOn ? .clear : PocketColor.surfaceBorder))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// The running answer under the pickers: the names so far, and in fret mode the tab as it builds.
struct NamingResultView: View {
    let labels: [PieceLabel?]
    let openMidi: [Int]
    let spelling: NoteSpelling
    let mode: NamingMode
    let tuningLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(mode == .fret ? "Tab so far" : "What you have so far")
                .font(.futura(.caption))
                .textCase(.uppercase)
                .foregroundStyle(PocketColor.textSecondary)
            if mode == .fret {
                tab
            } else {
                Text(names.map { $0 ?? "?" }.joined(separator: " "))
                    .font(.futura(.title3))
                    .foregroundStyle(PocketColor.textPrimary)
                Text("\(names.compactMap { $0 }.count) of \(labels.count) named.")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(PocketColor.surfaceSubtle))
    }

    private var names: [String?] { labels.map { $0?.name(openMidi: openMidi, spelling: spelling) } }

    @ViewBuilder private var tab: some View {
        let notes = labels.compactMap { label -> TabLine.Note? in
            guard case .fretted(let string, let fret) = label else { return nil }
            return TabLine.Note(string: string, fret: fret)
        }
        if let text = TabLine.render(notes, openMidi: openMidi) {
            ScrollView(.horizontal, showsIndicators: false) {
                Text(text)
                    .font(.pocketMono(.footnote))
                    .foregroundStyle(PocketColor.textPrimary)
                    .fixedSize()
            }
            let unplaced = labels.count - notes.count
            if unplaced > 0 {
                Text("\(unplaced) not placed yet.")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        } else {
            Text("Pick a string and a fret for each note.")
                .font(.futura(.caption))
                .foregroundStyle(PocketColor.textSecondary)
        }
    }
}
