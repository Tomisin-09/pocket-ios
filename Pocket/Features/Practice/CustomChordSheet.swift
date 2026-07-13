import SwiftUI

/// The **custom-chord placer** (ADR 0084 slice 3, M4) — a full-screen, *tappable* chord box for any
/// voicing the curated grips can't express: jazz shells, extensions, altered dominants, D-root shapes,
/// anything bespoke. It's an editable twin of `ChordDiagramView`: strings are columns (low E left →
/// high e right), **tap a fret cell** to fret that string (tap it again to clear), and **tap the ✕/○
/// marker above the nut** to cycle a string muted ↔ open. A position control slides the window up the
/// neck so a shape can sit anywhere. Each sounded string shows its **scale degree** relative to the
/// lowest note (R / 3 / 5 / ♭7 …), so the intervals a shape spells read as you build it.
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
    /// Lowest fret the board window shows (≥ 1); the position control scrolls it up the neck so a high
    /// voicing can be placed without an endless grid. Fret 0 (open) lives in the marker row, not a row.
    @State private var lowestVisibleFret = 1

    private static let visibleFretCount = 5
    private static let maxLowestFret = 12
    private let cellSize: CGFloat = 44
    private let markerHeight: CGFloat = 30
    private let nameHeight: CGFloat = 22

    /// Column order left → right: low E (index 5) … high e (index 0), the way a chord box faces you.
    private let columns = Array((0..<ChordVoicing.stringCount).reversed())
    /// String names by index (0 = high e … 5 = low E), drawn under each column.
    private let stringNames = ["e", "B", "G", "D", "A", "E"]

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var voicing: ChordVoicing { ChordVoicing(trimmedName, frets: frets) }
    private var canInsert: Bool { voicing.isValid && !trimmedName.isEmpty }
    private var degreeLabels: [String?] { voicing.degreeLabels }
    private var showsNut: Bool { lowestVisibleFret == 1 }

    private var gridWidth: CGFloat { cellSize * CGFloat(ChordVoicing.stringCount) }
    private var gridHeight: CGFloat { cellSize * CGFloat(Self.visibleFretCount) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 22) {
                titleLabel
                board
                positionControls
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

    // MARK: - Title (the live name, like the diagram's caption)

    private var titleLabel: some View {
        Text(trimmedName.isEmpty ? "New chord" : trimmedName)
            .font(.futura(.title2, weight: .semibold))
            .foregroundStyle(trimmedName.isEmpty ? PocketColor.textSecondary : PocketColor.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - The tappable chord box

    private var board: some View {
        HStack(alignment: .top, spacing: 6) {
            fretNumberGutter
            VStack(spacing: 0) {
                markerRow
                    .frame(width: gridWidth, height: markerHeight)
                ZStack {
                    gridLines
                    dots
                    interactiveCells
                }
                .frame(width: gridWidth, height: gridHeight)
                stringNamesRow
                    .frame(width: gridWidth, height: nameHeight)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Fret numbers down the left, aligned to each grid row (a blank spacer keeps them off the marker
    /// row above and the string names below).
    private var fretNumberGutter: some View {
        VStack(spacing: 0) {
            Color.clear.frame(width: 18, height: markerHeight)
            ForEach(0..<Self.visibleFretCount, id: \.self) { row in
                Text("\(lowestVisibleFret + row)")
                    .font(.futura(.caption2))
                    .foregroundStyle(PocketColor.textSecondary)
                    .frame(width: 18, height: cellSize)
            }
            Color.clear.frame(width: 18, height: nameHeight)
        }
    }

    /// ✕ (muted) / ○ (open) over each string, tappable to cycle. An open string also shows its degree.
    private var markerRow: some View {
        ZStack {
            ForEach(columns.indices, id: \.self) { column in
                let string = columns[column]
                Button { toggleMarker(string) } label: {
                    VStack(spacing: 0) {
                        Text(markerSymbol(string))
                            .font(.futura(.caption, weight: .semibold))
                            .foregroundStyle(PocketColor.textSecondary)
                        if frets[string] == 0, let degree = degreeLabels[string] {
                            Text(degree)
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

    /// The string lines (columns) and fret wires (rows), plus a thick nut when the window is at fret 1.
    private var gridLines: some View {
        ZStack {
            Path { path in
                for row in 0...Self.visibleFretCount {
                    let posY = CGFloat(row) * cellSize
                    path.move(to: CGPoint(x: columnCenter(0), y: posY))
                    path.addLine(to: CGPoint(x: columnCenter(columns.count - 1), y: posY))
                }
                for column in columns.indices {
                    let posX = columnCenter(column)
                    path.move(to: CGPoint(x: posX, y: 0))
                    path.addLine(to: CGPoint(x: posX, y: gridHeight))
                }
            }
            .stroke(PocketColor.gridLine, lineWidth: 1)

            if showsNut {
                Path { path in
                    path.move(to: CGPoint(x: columnCenter(0), y: 0))
                    path.addLine(to: CGPoint(x: columnCenter(columns.count - 1), y: 0))
                }
                .stroke(PocketColor.textPrimary, lineWidth: 3)
            }
        }
    }

    /// A filled tint dot with its degree for every fretted string inside the window.
    private var dots: some View {
        ForEach(columns.indices, id: \.self) { column in
            let string = columns[column]
            if let fret = frets[string], fret >= lowestVisibleFret,
               fret < lowestVisibleFret + Self.visibleFretCount {
                let row = fret - lowestVisibleFret
                ZStack {
                    Circle().fill(PocketColor.practice)
                    if let degree = degreeLabels[string] {
                        Text(degree)
                            .font(.futura(.caption2, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: cellSize * 0.74, height: cellSize * 0.74)
                .position(x: columnCenter(column), y: rowCenter(row))
            }
        }
    }

    /// Transparent tap targets over every cell — one per string × visible fret — mapping a tap to a
    /// fret placement. Sits above the grid lines so the whole box is live.
    private var interactiveCells: some View {
        VStack(spacing: 0) {
            ForEach(0..<Self.visibleFretCount, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(columns.indices, id: \.self) { column in
                        let string = columns[column]
                        let fret = lowestVisibleFret + row
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

    // MARK: - Position control

    private var positionControls: some View {
        HStack(spacing: 18) {
            Button { moveWindow(-1) } label: { Image(systemName: "chevron.left") }
                .disabled(lowestVisibleFret <= 1)
            Text("Frets \(lowestVisibleFret)–\(lowestVisibleFret + Self.visibleFretCount - 1)")
                .font(.futura(.subheadline, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
                .frame(minWidth: 130)
            Button { moveWindow(1) } label: { Image(systemName: "chevron.right") }
                .disabled(lowestVisibleFret >= Self.maxLowestFret)
        }
        .tint(PocketColor.practice)
    }

    // MARK: - Name + hint

    private var nameField: some View {
        TextField("Name this chord (e.g. Cadd9, F♯7♯9)", text: $name)
            .font(.futura(.body))
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
    }

    private var hint: some View {
        Text("Tap a fret to place it. Tap ✕ / ○ above a string to mute or open it. Dots show each note's "
            + "degree from the lowest string.")
            .font(.futura(.caption))
            .foregroundStyle(PocketColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Geometry helpers

    private func columnCenter(_ column: Int) -> CGFloat { (CGFloat(column) + 0.5) * cellSize }
    private func rowCenter(_ row: Int) -> CGFloat { (CGFloat(row) + 0.5) * cellSize }
    private func stringName(_ string: Int) -> String { stringNames[string] }

    // MARK: - Edits (map a tap to a fret change)

    /// Fret `string` at `fret`; tapping the string's own fret again clears it back to muted.
    private func placeFret(string: Int, fret: Int) {
        frets[string] = (frets[string] == fret) ? nil : fret
        haptic(.light)
    }

    /// The marker chooses the string's *non-fretted* state — muted → open → muted; a fretted string
    /// steps to open (removing the fret), the natural "un-fret from the top" gesture.
    private func toggleMarker(_ string: Int) {
        switch frets[string] {
        case .none: frets[string] = 0
        case .some(0): frets[string] = nil
        default: frets[string] = 0
        }
        haptic(.light)
    }

    private func markerSymbol(_ string: Int) -> String {
        switch frets[string] {
        case .none: return "✕"
        case .some(0): return "○"
        default: return ""
        }
    }

    private func markerAccessibility(_ string: Int) -> String {
        switch frets[string] {
        case .none: return "muted"
        case .some(0): return "open"
        case .some(let fret): return "fret \(fret)"
        }
    }

    private func moveWindow(_ delta: Int) {
        lowestVisibleFret = min(Self.maxLowestFret, max(1, lowestVisibleFret + delta))
        haptic(.light)
    }
}

#Preview("Custom chord placer") {
    Color.clear
        .fullScreenCover(isPresented: .constant(true)) {
            CustomChordSheet { _ in }
                .preferredColorScheme(.dark)
        }
}
