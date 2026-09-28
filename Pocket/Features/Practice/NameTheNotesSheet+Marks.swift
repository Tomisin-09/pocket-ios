import SwiftUI

// The five playing marks (ADR 0227 D5), under the neck. A bend changes the note and vibrato colours it, so
// both live on the note; hammer-on, pull-off and slide join two notes, so they live on the second, as
// *Into it*. The direction decides which join it is, so the control only offers the one that fits. Split
// out for file length.
extension NameTheNotesSheet {

    var marksControls: some View {
        let note = ringedNote
        let direction = NeckJoin.direction(into: active, of: labels)
        let into = currentJoin
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                pickerLabel("Into it").frame(width: 44, alignment: .leading)
                MarkSegments(options: [
                    .init(title: "Picked", isOn: note != nil && into == nil, isEnabled: note != nil) { setInto(nil) },
                    .init(title: direction?.legatoName ?? "Hammer-on", isOn: into == .legato,
                          isEnabled: direction != nil) { setInto(.legato) },
                    .init(title: "Slide", isOn: into == .slide, isEnabled: direction != nil) { setInto(.slide) }
                ])
            }
            if let hint = joinHint {
                Text(hint)
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
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
        }
    }

    private func bendRow(_ note: FrettedNote?) -> some View {
        HStack(spacing: 8) {
            pickerLabel("Bend").frame(width: 44, alignment: .leading)
            MarkSegments(options: FrettedNote.bends.map { bend in
                .init(title: Self.bendTitle(bend), isOn: note?.bend == bend, isEnabled: note != nil) {
                    mark { $0.bend = bend }
                }
            })
        }
    }

    private func vibratoButton(_ note: FrettedNote?) -> some View {
        Button {
            mark { $0.vibrato.toggle() }
        } label: {
            Text("~ Vibrato")
                .font(.futura(.footnote, weight: note?.vibrato == true ? .bold : nil))
                .padding(.horizontal, 10)
                .frame(minHeight: 32)
                .foregroundStyle(note?.vibrato == true ? PocketColor.background : PocketColor.textPrimary)
                .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(note?.vibrato == true ? PocketColor.practice : .clear))
                .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(note?.vibrato == true ? .clear : PocketColor.surfaceBorder))
        }
        .buttonStyle(.plain)
        .disabled(note == nil)
        .opacity(note == nil ? 0.35 : 1)
        .accessibilityAddTraits(note?.vibrato == true ? .isSelected : [])
    }

    /// The join stored on the note being named, fitting or not.
    private var currentJoin: Join? {
        guard case .fretted(_, let into) = labels[active] else { return nil }
        return into
    }

    /// What a bend button says: *None*, *½*, *Whole*, *1½* (steps).
    nonisolated static func bendTitle(_ semitones: Int) -> String {
        ["None", "½", "Whole", "1½"][min(max(semitones, 0), 3)]
    }

    /// Why *Into it* is off, said plainly, or `nil` when a join can go here.
    private var joinHint: String? {
        switch NeckJoin.blocker(into: active, of: labels) {
        case nil: return nil
        case .notPlaced: return "Place the note first."
        case .first: return "The first note has nothing before it."
        case .previousUnnamed: return "Name the note before this one first."
        case .previousByEar: return "The note before isn’t on the neck."
        case .otherStrings:
            let shape = (labels[active]?.frettedNotes.count ?? 0) > 1
                || (active > 0 && (labels[active - 1]?.frettedNotes.count ?? 0) > 1)
            return shape ? "Only from a shape on the same strings." : "Only from a note on the same string."
        case .sameFret: return "The note before is on the same fret."
        case .mixedDirections: return "Every note has to move the same way."
        }
    }

    private func setInto(_ join: Join?) {
        guard case .fretted(let notes, _) = labels[active] else { return }
        labels[active] = .fretted(notes, into: join)
    }

    /// The note bend and vibrato go on: the one note, or a shape's ringed note (0227 D5).
    private var ringedNote: FrettedNote? {
        let notes = labels[active]?.frettedNotes ?? []
        return notes.first { $0.string == ringed } ?? notes.last
    }

    /// Change the marks on the note being named, or on a shape's ringed note.
    private func mark(_ change: (inout FrettedNote) -> Void) {
        guard case .fretted(var notes, let into) = labels[active], !notes.isEmpty else { return }
        let index = notes.firstIndex { $0.string == ringed } ?? notes.count - 1
        change(&notes[index])
        labels[active] = .fretted(notes, into: into)
    }
}

/// A row of small segments where each can be off on its own, which `Picker(.segmented)` can't do: *Into it*
/// offers only the join that fits.
struct MarkSegments: View {
    struct Option {
        let title: String
        let isOn: Bool
        let isEnabled: Bool
        let action: () -> Void
    }

    let options: [Option]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                Button(action: option.action) {
                    Text(option.title)
                        .font(.futura(.footnote, weight: option.isOn ? .bold : nil))
                        .lineLimit(1)
                        .padding(.horizontal, 9)
                        .frame(minWidth: 38, minHeight: 28)
                        .foregroundStyle(PocketColor.textPrimary)
                        .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(option.isOn ? PocketColor.surfaceBorder : .clear))
                }
                .buttonStyle(.plain)
                .disabled(!option.isEnabled)
                .opacity(option.isEnabled ? 1 : 0.35)
                .accessibilityAddTraits(option.isOn ? .isSelected : [])
            }
        }
        .padding(2)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(PocketColor.surfaceSubtle))
        .fixedSize()
    }
}

/// The note being named's marks, drawn on the neck (ADR 0227 D5): a bend as an arrow to a dashed ghost
/// where it lands (the fretLIVE idea), vibrato as a wave over the note, a hammer-on or pull-off as a curve
/// under the string marked *h* or *p*, a slide as an arrow marked `/` or `\`. Only the current note's.
struct NeckMarksLayer: View {
    let notes: [FrettedNote]
    /// The tap before's notes, where a join starts.
    let previous: [FrettedNote]
    /// The join into this tap as written (`h`, `p`, `/`, `\`), when it has one that fits.
    let join: String?
    let stringCount: Int
    let maxFret: Int
    let headroom: CGFloat

    var body: some View {
        Canvas { context, _ in
            let ink = GraphicsContext.Shading.color(PocketColor.practice)
            let line = StrokeStyle(lineWidth: 1.75, lineCap: .round, lineJoin: .round)
            drawShapeLinks(in: context, ink: ink)
            for note in notes {
                drawNoteMarks(note, in: context, ink: ink, line: line)
            }
            if let join { drawJoin(join, in: context, ink: ink, line: line) }
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

    private func drawJoin(_ join: String, in context: GraphicsContext, ink: GraphicsContext.Shading,
                          line: StrokeStyle) {
        for (position, note) in notes.sorted(by: { $0.string < $1.string }).enumerated() {
            guard let before = previous.first(where: { $0.string == note.string }) else { continue }
            let start = center(note.string, before.fret)
            let end = center(note.string, note.fret)
            let middle = (start.x + end.x) / 2
            if join == "h" || join == "p" {
                var curve = Path()
                curve.move(to: CGPoint(x: start.x, y: start.y + 13))
                curve.addQuadCurve(to: CGPoint(x: end.x, y: end.y + 13), control: CGPoint(x: middle, y: end.y + 29))
                context.stroke(curve, with: ink, style: line)
                if position == 0 { pill(join, at: CGPoint(x: middle, y: end.y + 21), in: context) }
            } else {
                let way: CGFloat = end.x > start.x ? 1 : -1
                let tail = CGPoint(x: start.x + way * 6, y: end.y + 17)
                let tip = CGPoint(x: end.x - way * 9, y: end.y + 17)
                var arrow = Path()
                arrow.move(to: tail)
                arrow.addLine(to: tip)
                context.stroke(arrow, with: ink, style: line)
                context.fill(arrowhead(at: tip, from: tail), with: ink)
                if position == 0 { pill(join, at: CGPoint(x: middle, y: end.y + 17), in: context) }
            }
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
        context.stroke(Path(ellipseIn: box), with: .color(PocketColor.practice), lineWidth: 1)
        context.draw(Text(text).font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(PocketColor.practice), at: point)
    }
}
