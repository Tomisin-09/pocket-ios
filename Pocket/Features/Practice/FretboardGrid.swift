import SwiftUI

/// The **presentational fretboard** (ADR 0065 build 2): a string × fret grid with the drill's notes
/// plotted faintly and an optional `activeIndex` lit as the run walks the board. Holds no timing
/// logic — the caller decides which note is active (the live `FretboardView` computes it from the
/// clock; a static read passes `nil`). Reused so any preview and the running board are identical.
///
/// **T10** — every colour resolves through a semantic `PocketColor` role: the strings and fret
/// separators via the grid-line role, the nut and labels via the ink roles, plotted notes a dimmed
/// ink, and the active note in the content `tint` — so the board reskins under light/dark and any
/// future theme. `FretLabelMode` (the caption preference) lives beside this file.
struct FretboardGrid: View {
    let drill: FretboardDrill
    /// The note lit now, or `nil` for a static (nothing-lit) read.
    var activeIndex: Int?
    var tint: Color = PocketColor.practice
    /// How to caption each note (note name / interval / nothing).
    var labelMode: FretLabelMode = .none

    private var stringCount: Int { max(1, drill.stringCount) }
    /// The visible neck window (ADR 0083 S5). At rest it is the drill's full static span; while a long
    /// climb walks it follows the active note, so `span`/`lowestFret` here are window-relative.
    private var window: FretWindow { drill.displayWindow(activeIndex: activeIndex) }
    private var span: Int { max(1, window.span) }
    private var lowestFret: Int { window.lowestFret }

    /// Whether a note falls inside the visible window — open notes (fret 0) always show on the nut; a
    /// fretted note shows only within `[lowestFret, lowestFret + span)`. In the static full-window case
    /// this is true for every plotted note, so the at-rest board is unchanged.
    private func isVisible(_ note: FretNote) -> Bool {
        note.fret == 0 || (note.fret >= lowestFret && note.fret < lowestFret + span)
    }

    /// Width of the string-label gutter, and the spacing to the board — shared by the fret-number row so
    /// its numbers line up under the board columns.
    private static let labelGutter: CGFloat = 16
    private static let labelSpacing: CGFloat = 8

    /// Height of the fret-number row under the board — the labels column reserves the same below its
    /// names so it shares the board's height exactly (see `body`).
    private static let fretNumberRowHeight: CGFloat = 12

    var body: some View {
        // Two columns — labels and board — each a VStack of [content, a fixed-height spacer matching the
        // fret-number row]. Because the spacer is a *fixed* 12pt (not a flexible filler), the board keeps
        // its full height and the string names share it, so labels align to their string lines instead of
        // drifting down over the number row (ADR 0116 S5 alignment fix — the board is *not* compressed).
        HStack(alignment: .top, spacing: Self.labelSpacing) {
            VStack(spacing: 4) {
                stringLabels
                // Both dimensions fixed: width to the label gutter (a loose width would let this column
                // expand and push the board right), height to the fret-number row (so labels share the
                // board's height without a flexible filler compressing it).
                Color.clear.frame(width: Self.labelGutter, height: Self.fretNumberRowHeight)
            }
            VStack(spacing: 4) {
                board
                fretNumbers
            }
        }
        .frame(height: 168)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Fretboard drill: \(accessibilitySummary)")
    }

    /// The string names down the left edge (high e at top … low E at bottom), aligned to the rows.
    private var stringLabels: some View {
        GeometryReader { geo in
            ForEach(0..<stringCount, id: \.self) { row in
                Text(Self.stringName(row, of: stringCount))
                    .font(.futura(.caption2, weight: .semibold))
                    .foregroundStyle(PocketColor.textSecondary)
                    .position(x: 8, y: rowY(row, in: geo.size.height))
            }
        }
        .frame(width: Self.labelGutter)
    }

    /// The board itself: string lines, fret separators + nut, inlay markers, and the plotted / active
    /// note dots.
    private var board: some View {
        GeometryReader { geo in
            let width = geo.size.width, height = geo.size.height
            ZStack {
                stringLines(width: width, height: height)
                fretSeparators(width: width, height: height)
                nut(height: height)
                inlayDots(width: width, height: height)
                slideCues(width: width, height: height)
                walkTrail(width: width, height: height)
                notes(width: width, height: height)
            }
        }
    }

    /// The standard guitar position markers (single dot at 3·5·7·9·15·17·19·21, double at 12·24) that
    /// fall within the visible fret window — a faint orientation cue, same as the wood inlays on a
    /// real neck, so "which position is this" reads at a glance without counting fret lines. Internal
    /// so the authoring boards mark the same frets from the same list rather than a second copy of it.
    static let singleInlayFrets: Set<Int> = [3, 5, 7, 9, 15, 17, 19, 21]
    static let doubleInlayFrets: Set<Int> = [12, 24]

    private func inlayDots(width: CGFloat, height: CGFloat) -> some View {
        let visible = lowestFret..<(lowestFret + span)
        return ForEach(Array(visible), id: \.self) { fret in
            if Self.doubleInlayFrets.contains(fret) {
                inlayDot(diameter: 6, at: CGPoint(x: noteX(fret, in: width), y: height * 0.3))
                inlayDot(diameter: 6, at: CGPoint(x: noteX(fret, in: width), y: height * 0.7))
            } else if Self.singleInlayFrets.contains(fret) {
                inlayDot(diameter: 6, at: CGPoint(x: noteX(fret, in: width), y: height / 2))
            }
        }
    }

    /// A faint **connector trail** from the note just played to the one lit now, drawn only while the
    /// board is walking (2026-07-28). Sequenced runs — thirds, fourths, rolling groups — jump around a
    /// box, and with every dot the same size the *direction* of the jump was the part that didn't read.
    /// One segment, not a full path: the trail says "you came from there", it doesn't re-draw the run.
    /// A slide already has its own arrow, so this yields to `slideCues` on that pairing.
    @ViewBuilder
    private func walkTrail(width: CGFloat, height: CGFloat) -> some View {
        if let activeIndex, activeIndex > 0,
           drill.notes.indices.contains(activeIndex),
           let to = drill.notes[activeIndex], let from = drill.notes[activeIndex - 1],
           from != to, to.technique != .slide, isVisible(from), isVisible(to) {
            Path { path in
                path.move(to: CGPoint(x: noteX(from.fret, in: width), y: rowY(from.string, in: height)))
                path.addLine(to: CGPoint(x: noteX(to.fret, in: width), y: rowY(to.string, in: height)))
            }
            .stroke(tint.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .allowsHitTesting(false)
        }
    }

    private func inlayDot(diameter: CGFloat, at point: CGPoint) -> some View {
        Circle()
            .fill(PocketColor.gridLine)
            .frame(width: diameter, height: diameter)
            .position(point)
    }

    private func stringLines(width: CGFloat, height: CGFloat) -> some View {
        ForEach(0..<stringCount, id: \.self) { row in
            Rectangle()
                .fill(PocketColor.gridLine)
                .frame(width: width, height: 1)
                .position(x: width / 2, y: rowY(row, in: height))
        }
    }

    private func fretSeparators(width: CGFloat, height: CGFloat) -> some View {
        ForEach(0...span, id: \.self) { column in
            Rectangle()
                .fill(PocketColor.gridLine)
                .frame(width: 1, height: height)
                .position(x: CGFloat(column) / CGFloat(span) * width, y: height / 2)
        }
    }

    /// A thicker rule at the left edge — the nut open strings hang off of.
    private func nut(height: CGFloat) -> some View {
        Rectangle()
            .fill(PocketColor.textSecondary)
            .frame(width: 2.5, height: height)
            .position(x: 0, y: height / 2)
    }

    /// Every note the drill uses, plotted faintly; the active one lit and enlarged. Root notes (a
    /// scale/arpeggio's tonic, when the drill names one) carry the amber `marker` accent so the tonic
    /// is identifiable at rest, in the preview, and as the run walks over it.
    private func notes(width: CGFloat, height: CGFloat) -> some View {
        let active = activeIndex.flatMap { drill.note(at: $0) }
        // One dot per distinct **position**, not per played slot: a sequenced run sounds the same fret
        // several times, and a dot per slot stacked its own translucency into a solid white blob while
        // the least-repeated notes stayed grey (see `FretboardDrill.plottedPositions`).
        return ForEach(drill.plottedPositions, id: \.note) { entry in
            if isVisible(entry.note) {
                let isActive = activeIndex.map { entry.indices.contains($0) } ?? false
                let isRoot = isRoot(entry.note)
                let diameter = dotDiameter(isActive: isActive, isRoot: isRoot)
                let focus = passFocusOpacity(noteIndices: entry.indices)
                Circle()
                    .fill(fill(isActive: isActive, isRoot: isRoot))
                    .frame(width: diameter, height: diameter)
                    .overlay(rootRing(isRoot: isRoot, isActive: isActive))
                    .overlay(noteLabel(entry.note, isActive: isActive, isRoot: isRoot))
                    .opacity(focus)
                    .position(x: noteX(entry.note.fret, in: width),
                              y: rowY(entry.note.string, in: height))
                    .animation(.easeOut(duration: 0.07), value: isActive)
                    .animation(.easeOut(duration: 0.14), value: focus)
            }
        }
        // Keep the enlarged active dot on top even where notes share a cell.
        .zIndex(active == nil ? 0 : 1)
    }

    /// How faint an **off-pass** note fades to while a multi-pass run walks (ADR 0083 S2b — "pass
    /// focus"): the current pass reads as the focus, the rest stays visible as context. Feel value.
    private static let offPassGhostOpacity: Double = 0.2

    /// Whether the drill is a genuine multi-pass run — the gate for pass focus. A single-pass run tags
    /// one uniform group, and every non-run drill has no groups at all, so neither ever dims.
    private var isMultiPass: Bool {
        guard let groups = drill.noteGroups else { return false }
        return Set(groups).count > 1
    }

    /// The opacity for a position under **pass focus** (ADR 0083 S2b): while a multi-pass run walks,
    /// notes outside the active note's pass drop to a ghost so the eye locks onto the position being
    /// played; the active pass, a single-pass run, and the static board (no `activeIndex`) render fully.
    ///
    /// Takes **every** slot that plays this position and keeps it lit if *any* of them belongs to the
    /// active pass — a position the run revisits across passes is genuinely part of the pass being
    /// played, so ghosting it because one of its other slots sits elsewhere would fade a note under the
    /// hand right now.
    private func passFocusOpacity(noteIndices: [Int]) -> Double {
        guard isMultiPass, let activeIndex, let groups = drill.noteGroups,
              groups.indices.contains(activeIndex)
        else { return 1 }
        let activeGroup = groups[activeIndex]
        let sharesPass = noteIndices.contains { groups.indices.contains($0) && groups[$0] == activeGroup }
        return sharesPass ? 1 : Self.offPassGhostOpacity
    }

    /// Dot size — enlarged when captions are on so a "♭7" fits, and enlarged again when lit.
    private func dotDiameter(isActive: Bool, isRoot: Bool) -> CGFloat {
        let hasLabel = labelMode != .none
        if isActive { return hasLabel ? 21 : 18 }
        return hasLabel ? 18 : (isRoot ? 13 : 12)
    }

    /// The dot fill. A root reads as a **hollow amber ring** at rest (board-coloured centre so the
    /// amber `rootRing` stroke shows) and a **solid amber** dot when it lights; a non-root lights in
    /// the tint and rests as a faint ink dot. Captioned idle dots fill a touch stronger so the text
    /// sits on a legible chip.
    private func fill(isActive: Bool, isRoot: Bool) -> Color {
        if isRoot { return isActive ? PocketColor.marker : PocketColor.background }
        if isActive { return tint }
        return PocketColor.textPrimary.opacity(labelMode == .none ? 0.22 : 0.32)
    }

    /// The note's caption (note name or interval), coloured to read on its dot. Absent in `.none`
    /// mode and for interval mode on a rootless drill.
    @ViewBuilder
    private func noteLabel(_ note: FretNote, isActive: Bool, isRoot: Bool) -> some View {
        if let text = label(for: note) {
            Text(text)
                .font(.system(size: 9, weight: .bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(labelColor(isActive: isActive, isRoot: isRoot))
        }
    }

    /// Text colour: dark ink on a lit (bright-filled) dot, amber on an idle root ring, faint-dot ink
    /// otherwise.
    private func labelColor(isActive: Bool, isRoot: Bool) -> Color {
        if isActive { return PocketColor.background }
        if isRoot { return PocketColor.marker }
        return PocketColor.textPrimary
    }

    /// The caption string for a note in the current mode, or `nil` when nothing should show.
    private func label(for note: FretNote) -> String? {
        let pitchClass = drill.pitchClass(of: note)
        switch labelMode {
        case .none: return nil
        case .note: return GuitarScale.noteName(forPitchClass: pitchClass)
        case .interval:
            guard let root = drill.rootPitchClass else { return nil }
            return Self.intervalNames[(((pitchClass - root) % 12) + 12) % 12]
        }
    }

    /// Scale-degree names for the twelve semitones above the root (sharp-side spelling, matching the
    /// app's sharp fretboard): R, ♭2, 2, ♭3, 3, 4, ♭5, 5, ♭6, 6, ♭7, 7.
    private static let intervalNames =
        ["R", "♭2", "2", "♭3", "3", "4", "♭5", "5", "♭6", "6", "♭7", "7"]

    /// A thin halo around a root so it separates from neighbours even where notes share a cell.
    @ViewBuilder
    private func rootRing(isRoot: Bool, isActive: Bool) -> some View {
        if isRoot {
            Circle().strokeBorder(PocketColor.marker, lineWidth: isActive ? 2 : 1.5)
        }
    }

    /// Whether a note sounds the drill's root pitch class (only when the drill names one) — resolved in
    /// the drill's own tuning so a bass root ring lands correctly (ADR 0116 S5).
    private func isRoot(_ note: FretNote) -> Bool {
        guard let root = drill.rootPitchClass else { return false }
        return drill.pitchClass(of: note) == root
    }

    private var fretNumbers: some View {
        GeometryReader { geo in
            ForEach(0..<span, id: \.self) { column in
                Text("\(lowestFret + column)")
                    .font(.futura(.caption2))
                    .foregroundStyle(PocketColor.textSecondary.opacity(0.7))
                    .position(x: (CGFloat(column) + 0.5) / CGFloat(span) * geo.size.width, y: 6)
            }
        }
        .frame(height: Self.fretNumberRowHeight)
    }

    // MARK: - Pure layout helpers

    /// Vertical centre of a string row.
    private func rowY(_ row: Int, in height: CGFloat) -> CGFloat {
        (CGFloat(row) + 0.5) / CGFloat(stringCount) * height
    }

    /// Horizontal centre of a fret. An open note (fret 0) sits on the nut at the left edge; a
    /// fretted note sits in the middle of its column within the display window.
    private func noteX(_ fret: Int, in width: CGFloat) -> CGFloat {
        guard fret > 0 else { return 0 }
        let column = fret - lowestFret
        return (CGFloat(column) + 0.5) / CGFloat(span) * width
    }

    /// Standard 6-string names top-to-bottom (high e … low E); other counts read as "String N".
    static func stringName(_ index: Int, of count: Int) -> String {
        let guitar = ["e", "B", "G", "D", "A", "E"]
        let bass = ["G", "D", "A", "E"]   // standard 4-string bass, highest-first (ADR 0116)
        if count == guitar.count, guitar.indices.contains(index) { return guitar[index] }
        if count == bass.count, bass.indices.contains(index) { return bass[index] }
        return "\(index + 1)"
    }

    private var accessibilitySummary: String {
        drill.notes.compactMap { note -> String? in
            guard let note else { return nil }
            let name = Self.stringName(note.string, of: stringCount)
            let position = note.fret == 0 ? "open" : "fret \(note.fret)"
            let how = note.technique.map { ", \($0.label)" } ?? ""
            let root = isRoot(note) ? ", root" : ""
            return "\(name) \(position)\(root)\(how)"
        }.joined(separator: "; ")
    }
}

// MARK: - Slide cues (ADR 0083 S8)

/// The slide-teaching arrows, split into an extension so the main type stays under the body-length
/// ceiling. One arrow per distinct **seam** — deduped for the same reason the note dots are
/// (`FretboardDrill.plottedPositions`): a sequenced run re-plays a seam several times, and one
/// translucent arrow per played slot stacked into a solid line.
extension FretboardGrid {
    func slideCues(width: CGFloat, height: CGFloat) -> some View {
        ForEach(slideSegments, id: \.self) { segment in
            SlideCue(fromX: noteX(segment.fromFret, in: width),
                     toX: noteX(segment.toFret, in: width),
                     midY: rowY(segment.string, in: height))
                .stroke(tint.opacity(activeIndex.map(segment.indices.contains) == true ? 0.95 : 0.55),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
    }

    /// One slide arrow per distinct **seam**, with the played slots that land on it. Deduped for the
    /// same reason the note dots are (`FretboardDrill.plottedPositions`): a sequenced run re-plays a
    /// seam several times, and one translucent arrow per slot stacked into a solid line.
    struct SlideSegment: Hashable {
        let string: Int
        let fromFret: Int
        let toFret: Int
        var indices: [Int] = []

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.string == rhs.string && lhs.fromFret == rhs.fromFret && lhs.toFret == rhs.toFret
        }
        func hash(into hasher: inout Hasher) {
            hasher.combine(string); hasher.combine(fromFret); hasher.combine(toFret)
        }
    }

    var slideSegments: [SlideSegment] {
        var order: [SlideSegment] = []
        for (index, entry) in drill.notes.enumerated() {
            guard let note = entry, note.technique == .slide, index > 0, isVisible(note),
                  let previous = drill.notes[index - 1], previous.string == note.string
            else { continue }
            let segment = SlideSegment(string: note.string, fromFret: previous.fret, toFret: note.fret)
            if let existing = order.firstIndex(of: segment) {
                order[existing].indices.append(index)
            } else {
                order.append(SlideSegment(string: note.string, fromFret: previous.fret,
                                          toFret: note.fret, indices: [index]))
            }
        }
        return order
    }
}
