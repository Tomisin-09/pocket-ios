import SwiftUI

/// The **custom-chord placer** (ADR 0084 slice 3, M4) — a full-screen, *tappable* chord box for any
/// voicing the curated grips can't express: jazz shells, extensions, altered dominants, D-root shapes,
/// anything bespoke. It's an editable twin of `ChordDiagramView`: strings are columns (low E left →
/// high e right), **tap a fret cell** to fret that string (tap it again to clear), and **tap the ✕/○
/// marker above the nut** to cycle a string muted ↔ open. The board **scrolls up the neck** (frets 1…15)
/// with the mute/open row and string names pinned, and inlay dots (3·5·7·9·12·15) mark position — so a
/// shape can sit anywhere without an endless grid or a paging control. A **Display** menu captions each
/// sounded string with its note name, its scale degree (R / 3 / 5 / ♭7 …), or nothing, sharing the same
/// global preference the scale boards use.
///
/// The player names the result (an arbitrary voicing has no derivable name, unlike a slid grip); it
/// lands as a plain `ChordVoicing` mixed inline (M4/M5 — same output type a grip emits, so the renderer,
/// progression, and run screen are untouched). Fingers stay omitted: the shared diagram doesn't draw
/// them, so the placer composes fretted geometry only, like the grips (ADR 0084 open question).
struct CustomChordSheet: View {
    /// Called with the composed voicing when the player confirms.
    let onInsert: (ChordVoicing) -> Void

    @Environment(\.dismiss) private var dismiss

    /// Per-string fret, high-e first (index 0 … 5 low E) — `nil` muted, `0` open, `n` fretted at n.
    /// Starts all muted: the player composes the shape from scratch.
    @State private var frets: [Int?] = Array(repeating: nil, count: ChordVoicing.stringCount)
    @State private var name: String = ""

    /// Caption mode for sounded strings — shared globally with the scale boards so chords and scales
    /// agree (ADR 0065). `interval` shows scale degrees, `note` shows note names, `none` hides labels.
    @AppStorage("fretboardLabelMode") private var storedLabelMode = FretLabelMode.none.rawValue
    private var labelMode: FretLabelMode { FretLabelMode(rawValue: storedLabelMode) ?? .none }

    /// The whole reachable window, top of neck down. The board scrolls; five rows are visible at once.
    private static let totalFretCount = 15
    private static let visibleFretCount = 5
    /// Inlay reference marks — the standard single dots, with a double at the octave (fret 12).
    private static let singleInlayFrets: Set<Int> = [3, 5, 7, 9, 15]
    private static let doubleInlayFret = 12

    private let cellSize: CGFloat = 44
    private let markerHeight: CGFloat = 30
    private let nameHeight: CGFloat = 22
    private let gutterWidth: CGFloat = 18
    private let columnSpacing: CGFloat = 6

    /// Column order left → right: low E (index 5) … high e (index 0), the way a chord box faces you.
    private let columns = Array((0..<ChordVoicing.stringCount).reversed())
    /// String names by index (0 = high e … 5 = low E), drawn under each column.
    private let stringNames = ["e", "B", "G", "D", "A", "E"]

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var voicing: ChordVoicing { ChordVoicing(trimmedName, frets: frets) }
    private var canInsert: Bool { voicing.isValid && !trimmedName.isEmpty }

    /// The caption for each string under the current Display mode; `nil` hides that string's label.
    private var labels: [String?] {
        switch labelMode {
        case .none: return Array(repeating: nil, count: frets.count)
        case .note: return voicing.noteLabels
        case .interval: return voicing.degreeLabels
        }
    }

    private var gridWidth: CGFloat { cellSize * CGFloat(ChordVoicing.stringCount) }
    private var gridContentHeight: CGFloat { cellSize * CGFloat(Self.totalFretCount) }
    private var viewportHeight: CGFloat { cellSize * CGFloat(Self.visibleFretCount) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                titleRow
                board
                nameField
                hint
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle("Custom chord")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Insert") {
                        onInsert(voicing)
                        dismiss()
                    }
                    .disabled(!canInsert)
                }
            }
        }
        .tint(PocketColor.practice)
    }

    // MARK: - Title + Display (the live name, plus the label toggle like the scale boards)

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(trimmedName.isEmpty ? "New chord" : trimmedName)
                .font(.futura(.title2, weight: .semibold))
                .foregroundStyle(trimmedName.isEmpty ? PocketColor.textSecondary : PocketColor.textPrimary)
            Spacer()
            displayMenu
        }
    }

    /// Note / Interval / Off, matching the scale editors' control and sharing their global preference.
    private var displayMenu: some View {
        Menu {
            Picker("Labels", selection: $storedLabelMode) {
                ForEach(FretLabelMode.allCases) { mode in
                    Text(mode.pickerLabel).tag(mode.rawValue)
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "slider.horizontal.3")
                Text("Display")
            }
            .font(.futura(.caption, weight: .semibold))
            .foregroundStyle(PocketColor.practice)
        }
        .accessibilityLabel("Display options: labels \(labelMode.pickerLabel)")
    }

    // MARK: - The tappable chord box (marker + names pinned, fret rows scroll)

    private var board: some View {
        VStack(spacing: 0) {
            pinnedRow(height: markerHeight) { markerRow }
            ScrollView(.vertical, showsIndicators: false) {
                HStack(alignment: .top, spacing: columnSpacing) {
                    fretNumberGutter
                    ZStack {
                        gridLines
                        inlays
                        dots
                        interactiveCells
                    }
                    .frame(width: gridWidth, height: gridContentHeight)
                }
            }
            .frame(height: viewportHeight)
            pinnedRow(height: nameHeight) { stringNamesRow }
        }
        .frame(maxWidth: .infinity)
    }

    /// A fixed row above/below the scroll, indented by the fret-number gutter so it aligns to the grid.
    private func pinnedRow<Content: View>(height: CGFloat, @ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: columnSpacing) {
            Color.clear.frame(width: gutterWidth, height: height)
            content()
                .frame(width: gridWidth, height: height)
        }
        .frame(maxWidth: .infinity)
    }

    /// Fret numbers down the left, one per scrolling row.
    private var fretNumberGutter: some View {
        VStack(spacing: 0) {
            ForEach(1...Self.totalFretCount, id: \.self) { fret in
                Text("\(fret)")
                    .font(.futura(.caption2))
                    .foregroundStyle(PocketColor.textSecondary)
                    .frame(width: gutterWidth, height: cellSize)
            }
        }
    }

    /// ✕ (muted) / ○ (open) over each string, tappable to cycle. An open string also shows its label.
    private var markerRow: some View {
        ZStack {
            ForEach(columns.indices, id: \.self) { column in
                let string = columns[column]
                Button { toggleMarker(string) } label: {
                    VStack(spacing: 0) {
                        Text(markerSymbol(string))
                            .font(.futura(.caption, weight: .semibold))
                            .foregroundStyle(PocketColor.textSecondary)
                        if frets[string] == 0, let label = labels[string] {
                            Text(label)
                                .font(.futura(.caption2, weight: .bold))
                                .foregroundStyle(PocketColor.practice)
                        }
                    }
                    .frame(width: cellSize, height: markerHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .position(x: columnCenter(column), y: markerHeight / 2)
                .accessibilityLabel("\(stringName(string)) string")
                .accessibilityValue(markerAccessibility(string))
                .accessibilityHint("Tap to toggle muted or open")
            }
        }
    }

    /// The string lines (columns) and fret wires (rows), plus the thick nut at the top of the neck.
    private var gridLines: some View {
        ZStack {
            Path { path in
                for row in 0...Self.totalFretCount {
                    let posY = CGFloat(row) * cellSize
                    path.move(to: CGPoint(x: columnCenter(0), y: posY))
                    path.addLine(to: CGPoint(x: columnCenter(columns.count - 1), y: posY))
                }
                for column in columns.indices {
                    let posX = columnCenter(column)
                    path.move(to: CGPoint(x: posX, y: 0))
                    path.addLine(to: CGPoint(x: posX, y: gridContentHeight))
                }
            }
            .stroke(PocketColor.gridLine, lineWidth: 1)

            Path { path in
                path.move(to: CGPoint(x: columnCenter(0), y: 0))
                path.addLine(to: CGPoint(x: columnCenter(columns.count - 1), y: 0))
            }
            .stroke(PocketColor.textPrimary, lineWidth: 3)
        }
    }

    /// Faint position markers — a single dot at 3·5·7·9·15, a double at the octave (12) — so the player
    /// orients on the neck the way real inlays do.
    private var inlays: some View {
        ForEach(1...Self.totalFretCount, id: \.self) { fret in
            let posY = rowCenter(fret - 1)
            if fret == Self.doubleInlayFret {
                inlayDot.position(x: gridWidth / 2 - cellSize * 0.8, y: posY)
                inlayDot.position(x: gridWidth / 2 + cellSize * 0.8, y: posY)
            } else if Self.singleInlayFrets.contains(fret) {
                inlayDot.position(x: gridWidth / 2, y: posY)
            }
        }
    }

    private var inlayDot: some View {
        Circle()
            .fill(PocketColor.gridLine)
            .frame(width: cellSize * 0.24, height: cellSize * 0.24)
    }

    /// A filled tint dot with its label for every fretted string in the window.
    private var dots: some View {
        ForEach(columns.indices, id: \.self) { column in
            let string = columns[column]
            if let fret = frets[string], fret >= 1, fret <= Self.totalFretCount {
                ZStack {
                    Circle().fill(PocketColor.practice)
                    if let label = labels[string] {
                        Text(label)
                            .font(.futura(.caption2, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: cellSize * 0.74, height: cellSize * 0.74)
                .position(x: columnCenter(column), y: rowCenter(fret - 1))
            }
        }
    }

    /// Transparent tap targets over every cell — one per string × fret — mapping a tap to a fret
    /// placement. Sits above the grid lines so the whole board is live.
    private var interactiveCells: some View {
        VStack(spacing: 0) {
            ForEach(1...Self.totalFretCount, id: \.self) { fret in
                HStack(spacing: 0) {
                    ForEach(columns.indices, id: \.self) { column in
                        let string = columns[column]
                        Button { placeFret(string: string, fret: fret) } label: {
                            Color.clear
                                .frame(width: cellSize, height: cellSize)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(stringName(string)) fret \(fret)")
                        .accessibilityHint(frets[string] == fret ? "Placed — tap to clear" : "Tap to place")
                    }
                }
            }
        }
    }

    private var stringNamesRow: some View {
        ZStack {
            ForEach(columns.indices, id: \.self) { column in
                Text(stringName(columns[column]))
                    .font(.futura(.caption2, weight: .semibold))
                    .foregroundStyle(PocketColor.textSecondary)
                    .position(x: columnCenter(column), y: nameHeight / 2)
            }
        }
    }

    // MARK: - Name + hint

    private var nameField: some View {
        TextField("Name this chord (e.g. Cadd9, F♯7♯9)", text: $name)
            .font(.futura(.body))
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
    }

    private var hint: some View {
        Text("Tap a fret to place it — the board scrolls up the neck; inlay dots mark frets 3, 5, 7, 9 "
            + "and 12. Tap ✕ / ○ above a string to mute or open it. Use Display to label notes or degrees.")
            .font(.futura(.caption))
            .foregroundStyle(PocketColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

}

// MARK: - Geometry + edit helpers

private extension CustomChordSheet {
    func columnCenter(_ column: Int) -> CGFloat { (CGFloat(column) + 0.5) * cellSize }
    func rowCenter(_ row: Int) -> CGFloat { (CGFloat(row) + 0.5) * cellSize }
    func stringName(_ string: Int) -> String { stringNames[string] }

    /// Fret `string` at `fret`; tapping the string's own fret again clears it back to muted.
    func placeFret(string: Int, fret: Int) {
        frets[string] = (frets[string] == fret) ? nil : fret
        haptic(.light)
    }

    /// The marker chooses the string's *non-fretted* state — muted → open → muted; a fretted string
    /// steps to open (removing the fret), the natural "un-fret from the top" gesture.
    func toggleMarker(_ string: Int) {
        switch frets[string] {
        case .none: frets[string] = 0
        case .some(0): frets[string] = nil
        default: frets[string] = 0
        }
        haptic(.light)
    }

    func markerSymbol(_ string: Int) -> String {
        switch frets[string] {
        case .none: return "✕"
        case .some(0): return "○"
        default: return ""
        }
    }

    func markerAccessibility(_ string: Int) -> String {
        switch frets[string] {
        case .none: return "muted"
        case .some(0): return "open"
        case .some(let fret): return "fret \(fret)"
        }
    }
}

#Preview("Custom chord placer") {
    Color.clear
        .fullScreenCover(isPresented: .constant(true)) {
            CustomChordSheet { _ in }
                .preferredColorScheme(.dark)
        }
}
