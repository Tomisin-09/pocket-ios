import SwiftUI

/// The **tappable chord box** — an editable twin of `ChordDiagramView`, extracted from `CustomChordSheet`
/// (ADR 0084 slice 3) so the placer can stay under the file-length ceiling and the board can be reused.
/// Strings are columns (low E left → high e right): tap a fret cell to fret/clear it, tap the ✕/○ marker
/// to cycle a string muted↔open. The board scrolls the neck (frets 1…15) with the marker/name rows pinned
/// and inlay dots for orientation.
///
/// Purely a board: it owns geometry + edit gestures and writes fret changes back through `frets`, but it
/// takes its per-string `labels` (notes / degrees / none) ready-made from the caller, which knows the
/// current chord candidate to measure degrees against. It emits its own light haptics on edit.
struct ChordBoardEditor: View {
    /// Per-string fret, high-e first (0…5 low E) — `nil` muted, `0` open, `n` fretted.
    @Binding var frets: [Int?]
    /// The caption for each sounded string, ready-made by the caller; `nil` hides that string's label.
    let labels: [String?]
    /// The accent the dots/labels are drawn in (the owning surface's tint — Practice, here).
    var tint: Color = PocketColor.practice

    /// The whole reachable window, top of neck down. The board scrolls; five rows are visible at once.
    /// **24, not 15** (2026-07-28): `ChordVoicing` never capped the fret, only this board did, and a
    /// voicing placed above the 15th had nowhere to go. 24 also gives the octave double-inlay a partner.
    private static let totalFretCount = 24
    private static let visibleFretCount = 5
    /// Inlay reference marks — read from `FretboardGrid` so the chord board marks the same frets as the
    /// drill boards rather than keeping a second, shorter list that stopped at 15.
    private static let singleInlayFrets = FretboardGrid.singleInlayFrets
    private static let doubleInlayFrets = FretboardGrid.doubleInlayFrets

    private let cellSize: CGFloat = 44
    private let markerHeight: CGFloat = 30
    private let nameHeight: CGFloat = 22
    private let gutterWidth: CGFloat = 18
    private let columnSpacing: CGFloat = 6

    /// How many strings this board edits — the bound shape's own length (ADR 0163), so the same
    /// editor serves a six-string guitar box and a four-string bass one.
    private var stringCount: Int { frets.count }
    /// Column order left → right: lowest string … highest, the way a chord box faces you.
    private var columns: [Int] { Array((0..<stringCount).reversed()) }
    /// String name by index (0 = highest), drawn under each column — shared with the drill boards so
    /// a bass board reads G D A E rather than a guitar's names on four columns.
    private func stringName(_ index: Int) -> String {
        FretboardGrid.stringName(index, of: stringCount)
    }

    private var gridWidth: CGFloat { cellSize * CGFloat(stringCount) }
    private var gridContentHeight: CGFloat { cellSize * CGFloat(Self.totalFretCount) }
    private var viewportHeight: CGFloat { cellSize * CGFloat(Self.visibleFretCount) }

    var body: some View {
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
                                .foregroundStyle(tint)
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

    /// Faint inlay markers — single dots at 3·5·7·9·15·17·19·21, doubles at the octaves (12 and 24) —
    /// for orientation, which matters more now the neck runs the full 24 frets.
    private var inlays: some View {
        ForEach(1...Self.totalFretCount, id: \.self) { fret in
            let posY = rowCenter(fret - 1)
            if Self.doubleInlayFrets.contains(fret) {
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
                    Circle().fill(tint)
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

    /// Transparent tap targets over every string × fret cell, above the grid lines so the board is live.
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

    // MARK: - Geometry + edit helpers

    private func columnCenter(_ column: Int) -> CGFloat { (CGFloat(column) + 0.5) * cellSize }
    private func rowCenter(_ row: Int) -> CGFloat { (CGFloat(row) + 0.5) * cellSize }

    /// Fret `string` at `fret`; tapping the string's own fret again clears it back to muted.
    private func placeFret(string: Int, fret: Int) {
        frets[string] = (frets[string] == fret) ? nil : fret
        haptic(.light)
    }

    /// The marker cycles the string's *non-fretted* state (muted → open → muted); a fretted string
    /// steps to open — the natural "un-fret from the top" gesture.
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
}

#Preview("Chord board editor") {
    struct Harness: View {
        @State private var frets: [Int?] = [3, 1, 0, 0, 3, nil] // C, roughly
        var body: some View {
            ChordBoardEditor(frets: $frets, labels: Array(repeating: nil, count: 6))
                .padding()
        }
    }
    return Harness().preferredColorScheme(.dark)
}
