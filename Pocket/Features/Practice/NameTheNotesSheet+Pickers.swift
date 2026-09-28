import SwiftUI

// Fret & string (ADR 0225, still on string buttons and a fret stepper until the neck lands, ADR 0227
// D3), the buttons both sheets share, and the running answer. Split out for file length.
extension NameTheNotesSheet {

    var sixColumns: [GridItem] { Array(repeating: GridItem(.flexible(), spacing: 6), count: 6) }

    // MARK: - Fret & string

    /// Strings from the piece's tuning, thinnest first like the tab, and a fret from 0 to 22. Placing a
    /// note over a name given by ear just replaces it: only overwriting neck work asks first (0227 D7).
    var fretPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let byEar = labels[active], !byEar.isOnTheNeck,
               let name = byEar.name(openMidi: tuning.openMidi, spelling: spelling) {
                Text("Named by ear as \(Text(name).bold()). It can’t be drawn here; placing a note replaces it.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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
                               state: currentFret?.string == item.offset ? .picked : .plain) {
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
        labels[active] = .fretted(string: string, fret: fret)
        replacing = nil
    }

    // MARK: - Shared

    /// How a pick button is lit: **picked** is the answer given on this sheet; **read** is what the other
    /// sheet's answer reads as here, outlined rather than filled, since it wasn't picked here (0227 D7).
    enum PickState {
        case plain, picked, read

        var ink: Color {
            switch self {
            case .plain: return PocketColor.textPrimary
            case .picked: return PocketColor.background
            case .read: return PocketColor.practice
            }
        }

        var fill: Color {
            switch self {
            case .plain: return PocketColor.surfaceSubtle
            case .picked: return PocketColor.textPrimary
            case .read: return .clear
            }
        }

        var edge: Color {
            switch self {
            case .plain: return PocketColor.surfaceBorder
            case .picked: return .clear
            case .read: return PocketColor.practice
            }
        }
    }

    func pickerLabel(_ text: String) -> some View {
        Text(text)
            .font(.futura(.caption))
            .foregroundStyle(PocketColor.textSecondary)
    }

    func pickButton(_ title: String, state: PickState, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.futura(.subheadline, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, minHeight: 40)
                .padding(.horizontal, 4)
                .foregroundStyle(state.ink)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(state.fill))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(state.edge, lineWidth: state == .read ? 2 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(state == .plain ? [] : .isSelected)
    }
}

/// The running answer under the pickers: the tab as it builds on Fret & string, the names on By ear. The
/// names scroll sideways with the current one lit, like the strip, so a long pass doesn't push the page.
struct NamingResultView: View {
    let labels: [PieceLabel?]
    let active: Int
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
            switch mode {
            case .fret: tab
            case .ear: names
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(PocketColor.surfaceSubtle))
    }

    @ViewBuilder private var names: some View {
        let names = labels.map { $0?.name(openMidi: openMidi, spelling: spelling) }
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(names.indices, id: \.self) { index in
                        Text(names[index] ?? "?")
                            .font(.futura(.title3, weight: index == active ? .bold : nil))
                            .foregroundStyle(index == active ? PocketColor.practice
                                             : names[index] == nil ? PocketColor.textSecondary
                                             : PocketColor.textPrimary)
                    }
                }
            }
            .onAppear { proxy.scrollTo(active, anchor: .center) }
            .onChange(of: active) { proxy.scrollTo(active, anchor: .center) }
        }
        Text("\(names.compactMap { $0 }.count) of \(labels.count) named.")
            .font(.futura(.caption))
            .foregroundStyle(PocketColor.textSecondary)
    }

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
