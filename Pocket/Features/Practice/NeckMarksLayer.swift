import SwiftUI

/// The note being named's marks, drawn on the neck (ADR 0227 D5): a bend as an arrow to a dashed ghost
/// where it lands (the fretLIVE idea), vibrato as a wave over the note, a hammer-on or pull-off as a curve
/// under the string marked *h* or *p*, a slide as an arrow marked `/` or `\`. A lead-in draws the same
/// curve or arrow from a ring where it started, or, from nowhere, a short arrow in. Only the current note's.
struct NeckMarksLayer: View {
    let notes: [FrettedNote]
    /// The tap before's notes, where a join starts.
    let previous: [FrettedNote]
    /// The join into this tap as written (`h`, `p`, `/`, `\`), when it has one that fits.
    let join: String?
    let stringCount: Int
    let maxFret: Int
    let headroom: CGFloat
    @Environment(\.neckAccent) private var accent

    var body: some View {
        Canvas { context, _ in
            let ink = GraphicsContext.Shading.color(accent)
            let line = StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round)
            drawShapeLinks(in: context, ink: ink)
            // A shape's lead-ins are one move: one pill, on its top string.
            let top = notes.map(\.string).min()
            for note in notes {
                drawNoteMarks(note, in: context, ink: ink, line: line)
                drawLeadIn(note, labelled: note.string == top, in: context)
            }
            if let join { drawJoin(join, in: context) }
        }
        .frame(width: CGFloat(maxFret + 1) * NeckGeometry.pitch,
               height: headroom + CGFloat(stringCount) * NeckGeometry.pitch + 20)
        .accessibilityHidden(true)
    }

    private func center(_ string: Int, _ fret: Int) -> CGPoint {
        NeckGeometry.center(string: string, fret: fret, headroom: headroom)
    }

    /// A shape's notes joined string to string, so a spread grip reads as one shape, not scattered dots.
    private func drawShapeLinks(in context: GraphicsContext, ink: GraphicsContext.Shading) {
        let sorted = notes.sorted { $0.string < $1.string }
        for (upper, lower) in zip(sorted, sorted.dropFirst()) {
            let start = center(upper.string, upper.fret)
            let end = center(lower.string, lower.fret)
            let length = hypot(end.x - start.x, end.y - start.y)
            guard length > 26 else { continue }
            let unit = CGPoint(x: (end.x - start.x) / length, y: (end.y - start.y) / length)
            var link = Path()
            link.move(to: CGPoint(x: start.x + unit.x * 12, y: start.y + unit.y * 12))
            link.addLine(to: CGPoint(x: end.x - unit.x * 12, y: end.y - unit.y * 12))
            context.stroke(link, with: ink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
    }

    private func drawNoteMarks(_ note: FrettedNote, in context: GraphicsContext, ink: GraphicsContext.Shading,
                               line: StrokeStyle) {
        let from = center(note.string, note.fret)
        let land = note.fret + note.bend
        let bendShows = note.bend > 0 && land <= maxFret
        if bendShows {
            let ghost = center(note.string, land)
            context.stroke(Path(ellipseIn: CGRect(x: ghost.x - 12, y: ghost.y - 12, width: 24, height: 24)),
                           with: ink, style: StrokeStyle(lineWidth: 1.5, dash: [3, 2.5]))
            let start = CGPoint(x: from.x + 4, y: from.y - 12)
            let control = CGPoint(x: (from.x + ghost.x) / 2 + 2, y: from.y - 34)
            let end = CGPoint(x: ghost.x - 3, y: ghost.y - 13)
            var arc = Path()
            arc.move(to: start)
            arc.addQuadCurve(to: end, control: control)
            context.stroke(arc, with: ink, style: line)
            context.fill(arrowhead(at: end, from: control), with: ink)
        }
        if note.vibrato {
            let over = bendShows ? center(note.string, land) : from
            var wave = Path()
            let left = over.x + (bendShows ? 3 : -9)
            wave.move(to: CGPoint(x: left, y: over.y - 17))
            for step in 0..<4 {
                let start = left + CGFloat(step) * 4.5
                wave.addQuadCurve(to: CGPoint(x: start + 4.5, y: over.y - 17),
                                  control: CGPoint(x: start + 2.25, y: over.y - 17 + (step.isMultiple(of: 2) ? -3 : 3)))
            }
            context.stroke(wave, with: ink, style: line)
        }
    }

    private func drawJoin(_ join: String, in context: GraphicsContext) {
        for (position, note) in notes.sorted(by: { $0.string < $1.string }).enumerated() {
            guard let before = previous.first(where: { $0.string == note.string }) else { continue }
            drawLink(join, from: center(note.string, before.fret), to: center(note.string, note.fret),
                     labelled: position == 0, in: context)
        }
    }

    /// A lead-in inside the note: a ring on the fret it started from, or from nowhere a short arrow in
    /// from the side it came, and the join's curve or arrow into the note.
    private func drawLeadIn(_ note: FrettedNote, labelled: Bool, in context: GraphicsContext) {
        guard let leadIn = note.leadIn, let way = leadIn.direction(into: note.fret) else { return }
        let end = center(note.string, note.fret)
        let start: CGPoint
        if case .fret(let fret) = leadIn.from {
            start = center(note.string, fret)
            context.stroke(Path(ellipseIn: CGRect(x: start.x - 12, y: start.y - 12, width: 24, height: 24)),
                           with: .color(accent), lineWidth: 1.5)
        } else {
            start = CGPoint(x: end.x + (way == .upward ? -1.4 : 1.4) * NeckGeometry.pitch, y: end.y)
        }
        drawLink(way.symbol(for: leadIn.join), from: start, to: end, labelled: labelled, in: context)
    }

    /// One join drawn under a string, `start` to `end`: a curve for *h* and *p*, an arrow for a slide, and
    /// the mark in a pill when `labelled` (once per shape).
    private func drawLink(_ join: String, from start: CGPoint, to end: CGPoint, labelled: Bool,
                          in context: GraphicsContext) {
        let ink = GraphicsContext.Shading.color(accent)
        let line = StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round)
        let middle = (start.x + end.x) / 2
        if join == "h" || join == "p" {
            var curve = Path()
            curve.move(to: CGPoint(x: start.x, y: start.y + 13))
            curve.addQuadCurve(to: CGPoint(x: end.x, y: end.y + 13), control: CGPoint(x: middle, y: end.y + 29))
            context.stroke(curve, with: ink, style: line)
            if labelled { pill(join, at: CGPoint(x: middle, y: end.y + 21), in: context) }
        } else {
            let way: CGFloat = end.x > start.x ? 1 : -1
            let tail = CGPoint(x: start.x + way * 6, y: end.y + 17)
            let tip = CGPoint(x: end.x - way * 9, y: end.y + 17)
            var arrow = Path()
            arrow.move(to: tail)
            arrow.addLine(to: tip)
            context.stroke(arrow, with: ink, style: line)
            context.fill(arrowhead(at: tip, from: tail), with: ink)
            if labelled { pill(join, at: CGPoint(x: middle, y: end.y + 17), in: context) }
        }
    }

    /// A small filled triangle at `tip`, pointing away from `from`.
    private func arrowhead(at tip: CGPoint, from: CGPoint) -> Path {
        let angle = atan2(tip.y - from.y, tip.x - from.x)
        let back = CGPoint(x: tip.x - 6 * cos(angle), y: tip.y - 6 * sin(angle))
        let side = CGPoint(x: -sin(angle) * 3.5, y: cos(angle) * 3.5)
        var head = Path()
        head.move(to: tip)
        head.addLine(to: CGPoint(x: back.x + side.x, y: back.y + side.y))
        head.addLine(to: CGPoint(x: back.x - side.x, y: back.y - side.y))
        head.closeSubpath()
        return head
    }

    private func pill(_ text: String, at point: CGPoint, in context: GraphicsContext) {
        let box = CGRect(x: point.x - 6.5, y: point.y - 6.5, width: 13, height: 13)
        context.fill(Path(ellipseIn: box), with: .color(PocketColor.background))
        context.stroke(Path(ellipseIn: box), with: .color(accent), lineWidth: 1)
        context.draw(Text(text).font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(accent), at: point)
    }
}
