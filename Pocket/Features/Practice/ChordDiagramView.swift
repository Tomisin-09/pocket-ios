import SwiftUI

/// The **presentational chord diagram** (ADR 0065) — a standard vertical chord box for one
/// `ChordVoicing`: six strings as columns (low E left → high e right), a four-fret window, dots for
/// fretted notes (finger number inside when known), and ×/○ over the nut for muted/open strings. A
/// high shape drops the nut for a "n fr." caption and windows at its lowest fret.
///
/// Pure and stateless — it just draws the voicing it's handed, so the live change view and any
/// static preview render pixel-identically. **T10**: every colour resolves through a semantic
/// `PocketColor` role (strings/frets the grid-line role, the nut and captions the ink roles, the
/// active dot the content `tint`), so it reskins under light/dark and any theme.
struct ChordDiagramView: View {
    let voicing: ChordVoicing
    /// The active chord shows solid `tint` dots; a dimmed "up next" preview passes `false`.
    var isActive: Bool = true
    var tint: Color = PocketColor.practice
    /// The Roman-numeral badge (I, V, vi …) shown beside the name, or `nil` to hide it.
    var degreeLabel: String?
    /// How many frets the window shows.
    var fretWindow: Int = 4

    /// Display order left → right: low E (index 5) first … high e (index 0) last — the standard way
    /// a chart is drawn when the guitar faces you.
    private let displayStrings = Array((0..<ChordVoicing.stringCount).reversed())
    private var baseFret: Int { voicing.displayBaseFret }
    private var showsNut: Bool { baseFret == 1 }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 5) {
                Text(voicing.name)
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(isActive ? PocketColor.textPrimary : PocketColor.textSecondary)
                if let degreeLabel {
                    Text(degreeLabel)
                        .font(.futura(.caption2, weight: .bold))
                        .foregroundStyle(isActive ? tint : PocketColor.textSecondary)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Capsule().fill((isActive ? tint : PocketColor.textSecondary)
                            .opacity(0.16)))
                }
            }
            GeometryReader { geo in
                board(in: geo.size)
            }
            .aspectRatio(0.82, contentMode: .fit)
        }
        .opacity(isActive ? 1 : 0.55)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    // MARK: - Layout

    /// Inset the grid so the ×/○ row sits above the nut and a "n fr." caption fits at the left.
    private func board(in size: CGSize) -> some View {
        let topInset: CGFloat = size.height * 0.16
        let leftInset: CGFloat = showsNut ? size.width * 0.04 : size.width * 0.16
        let gridWidth = size.width - leftInset - size.width * 0.04
        let gridHeight = size.height - topInset - size.height * 0.04
        let origin = CGPoint(x: leftInset, y: topInset)

        return ZStack(alignment: .topLeading) {
            gridLines(origin: origin, width: gridWidth, height: gridHeight)
            nut(origin: origin, width: gridWidth)
            baseFretCaption(origin: origin, height: gridHeight)
            stringMarkers(origin: origin, width: gridWidth, topInset: topInset)
            dots(origin: origin, width: gridWidth, height: gridHeight)
        }
    }

    private func columnX(_ column: Int, origin: CGPoint, width: CGFloat) -> CGFloat {
        origin.x + CGFloat(column) / CGFloat(ChordVoicing.stringCount - 1) * width
    }

    /// Vertical centre of the fret *space* holding an absolute `fret` (space 0 = the top window fret).
    private func spaceY(forFret fret: Int, origin: CGPoint, height: CGFloat) -> CGFloat {
        let space = CGFloat(fret - baseFret)
        return origin.y + (space + 0.5) / CGFloat(fretWindow) * height
    }

    // MARK: - Pieces

    private func gridLines(origin: CGPoint, width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            ForEach(0..<ChordVoicing.stringCount, id: \.self) { column in
                Path { path in
                    let posX = columnX(column, origin: origin, width: width)
                    path.move(to: CGPoint(x: posX, y: origin.y))
                    path.addLine(to: CGPoint(x: posX, y: origin.y + height))
                }
                .stroke(PocketColor.gridLine, lineWidth: 1)
            }
            ForEach(0...fretWindow, id: \.self) { row in
                Path { path in
                    let posY = origin.y + CGFloat(row) / CGFloat(fretWindow) * height
                    path.move(to: CGPoint(x: origin.x, y: posY))
                    path.addLine(to: CGPoint(x: origin.x + width, y: posY))
                }
                .stroke(PocketColor.gridLine, lineWidth: 1)
            }
        }
    }

    /// The thick top rule at fret 1 — only for open-position shapes.
    @ViewBuilder
    private func nut(origin: CGPoint, width: CGFloat) -> some View {
        if showsNut {
            Path { path in
                path.move(to: CGPoint(x: origin.x, y: origin.y))
                path.addLine(to: CGPoint(x: origin.x + width, y: origin.y))
            }
            .stroke(PocketColor.textPrimary, lineWidth: 3)
        }
    }

    /// "5 fr." to the left of the window's top space, for a shape sitting above the nut.
    @ViewBuilder
    private func baseFretCaption(origin: CGPoint, height: CGFloat) -> some View {
        if !showsNut {
            Text("\(baseFret) fr.")
                .font(.futura(.caption2))
                .foregroundStyle(PocketColor.textSecondary)
                .position(x: origin.x - 14, y: origin.y + 0.5 / CGFloat(fretWindow) * height)
        }
    }

    /// × for a muted string and ○ for an open one, above the nut.
    private func stringMarkers(origin: CGPoint, width: CGFloat, topInset: CGFloat) -> some View {
        ForEach(displayStrings.indices, id: \.self) { column in
            let stringIndex = displayStrings[column]
            let symbol = marker(forString: stringIndex)
            if let symbol {
                Text(symbol)
                    .font(.futura(.caption2, weight: .semibold))
                    .foregroundStyle(PocketColor.textSecondary)
                    .position(x: columnX(column, origin: origin, width: width), y: topInset * 0.42)
            }
        }
    }

    private func marker(forString stringIndex: Int) -> String? {
        switch voicing.frets[stringIndex] {
        case .none: return "✕"
        case .some(0): return "○"
        default: return nil
        }
    }

    /// A plain filled dot for each fretted string. Finger numbers are intentionally not drawn — at
    /// diagram scale they read as noise; the shape alone is what the player follows.
    private func dots(origin: CGPoint, width: CGFloat, height: CGFloat) -> some View {
        let diameter = min(width / CGFloat(ChordVoicing.stringCount - 1),
                           height / CGFloat(fretWindow)) * 0.62
        return ForEach(displayStrings.indices, id: \.self) { column in
            let stringIndex = displayStrings[column]
            if let fret = voicing.frets[stringIndex], fret > 0, fret >= baseFret,
               fret < baseFret + fretWindow {
                Circle()
                    .fill(isActive ? tint : PocketColor.textSecondary)
                    .frame(width: diameter, height: diameter)
                    .position(x: columnX(column, origin: origin, width: width),
                              y: spaceY(forFret: fret, origin: origin, height: height))
            }
        }
    }

    private var accessibilityLabel: String {
        let strings = voicing.frets.map { fret -> String in
            switch fret {
            case .none: return "muted"
            case .some(0): return "open"
            case .some(let value): return "fret \(value)"
            }
        }
        return "\(voicing.name) chord: high e \(strings[0]), \(strings[5]) low E"
    }
}

#Preview("Chord diagrams") {
    HStack(spacing: 16) {
        ChordDiagramView(voicing: .cMajor)
        ChordDiagramView(voicing: .dMajor, isActive: false)
        ChordDiagramView(voicing: .bMinorBarre)
        ChordDiagramView(voicing: .cTriad)
    }
    .frame(height: 160)
    .padding()
    .background(PocketColor.background)
    .preferredColorScheme(.dark)
}
