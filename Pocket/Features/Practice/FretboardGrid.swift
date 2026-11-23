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
    let activeIndex: Int?
    let tint: Color
    /// How to caption each note (note name / interval / nothing).
    let labelMode: FretLabelMode
    /// The visible neck window (ADR 0083 S5). At rest it is the drill's full static span; while a long
    /// climb walks it follows the active note, so `span`/`lowestFret` here are window-relative.
    ///
    /// **Worked out once, here**, not on each read. It was a computed property, and every fret line, fret
    /// number, inlay and dot read it, so a walking board ran `displayWindow` about a hundred and ten times
    /// a frame, each walking every note of the run. A Triads progression up the neck, played Together, is
    /// 96 slots of three notes, and that took 106 ms a frame in a Debug build against a 120 Hz budget of
    /// 8: the sheet around the board stuttered as it scrolled.
    private let window: FretWindow

    init(drill: FretboardDrill, activeIndex: Int? = nil, tint: Color = PocketColor.practice,
         labelMode: FretLabelMode = .none) {
        self.drill = drill
        self.activeIndex = activeIndex
        self.tint = tint
        self.labelMode = labelMode
        self.window = drill.displayWindow(activeIndex: activeIndex)
    }

    /// The **rootless** fallback spelling (ADR 0123). A drill that carries a key spells by that key;
    /// one that doesn't — a spider walk, a picking pattern, or a key the circle of fifths leaves open —
    /// follows the accidental preference read here, so a flats player never sees "A♯" on the board.
    @AppStorage(AppSettings.Key.accidentalPreference)
    private var accidentalRaw = NoteSpelling.default.rawValue
    /// Whether a jump between notes draws its arrow (`walkTrail`): the **Display** menu's switch.
    @AppStorage(AppSettings.Key.fretboardShowsMoves) private var showsMoves = AppSettings.fretboardShowsMovesDefault

    var spelling: NoteSpelling {
        drill.spelling(preference: NoteSpelling(rawValue: accidentalRaw) ?? .default)
    }

    var stringCount: Int { max(1, drill.stringCount) }
    private var span: Int { max(1, window.span) }
    private var lowestFret: Int { window.lowestFret }

    /// Whether a note falls inside the visible window (`FretWindow.shows`): an open note only while the
    /// nut is in view, a fretted note within `[lowestFret, lowestFret + span)`. In the static full-window
    /// case this is true for every plotted note, so the at-rest board is unchanged.
    private func isVisible(_ note: FretNote) -> Bool { window.shows(note) }

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
        // The neck's string count, stated where a UI test can read it. Which instrument a board is
        // drawing is otherwise only inferable from the string-name captions, which a note-label query
        // can't distinguish from a root picker's letters — and "the create sheet drew a guitar neck
        // for a bass drill" is exactly the defect this identifier exists to catch (ADR 0116).
        .accessibilityIdentifier(Self.stringCountIdentifier(stringCount))
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
                // A Triads run's range of frets (ADR 0313 D6), behind everything else. Draws nothing without one.
                FretRangeShade(range: drill.shadedFrets, lowestFret: lowestFret, span: span, tint: tint)
                stringLines(width: width, height: height)
                fretSeparators(width: width, height: height)
                nut(height: height)
                inlayDots(width: width, height: height)
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

    /// The **move** from the note just played to the one lit now, drawn only while the board is walking.
    /// Sequenced runs — thirds, fourths, rolling groups — jump around a box, and with every dot the same
    /// size the *direction* of the jump was the part that didn't read. It was a faint line from dot to dot
    /// (2026-07-28), which said the two were joined but not which way; it's a small arrowhead in the gap
    /// now (`MoveArrow`, 2026-11-21), and the **Display** menu turns it off. One step, not the run: it says
    /// "you came from there", it doesn't re-draw the path.
    ///
    /// **Slide seams travel this path too** (2026-07-28, amending ADR 0083 S8). The seams used to carry
    /// a permanently-drawn arrow, which on an extended pentatonic meant a static board full of arrows
    /// whatever the sequence — the clutter outweighed the cue. A seam now draws the same `SlideCue`
    /// arrowhead, but *as* the trail: only while it's the step being played, when the instruction
    /// "slide into this one" is actually actionable. The technique survives outside the walk in the
    /// accessibility summary, which reads it per note. A Legato drill's hammer-ons and pull-offs follow
    /// the same rule (ADR 0251, `LegatoCue`). A chord played Together is three fingers landing at once, not
    /// one finger's jump, so it draws no arrow: the dashed rings show where they came from (ADR 0313 D8).
    @ViewBuilder
    private func walkTrail(width: CGFloat, height: CGFloat) -> some View {
        if let activeIndex, activeIndex > 0, !drill.playsTogether,
           drill.notes.indices.contains(activeIndex),
           let to = drill.notes[activeIndex], let from = drill.notes[activeIndex - 1],
           from != to, isVisible(from), isVisible(to) {
            let fromPoint = CGPoint(x: noteX(from.fret, in: width), y: rowY(from.string, in: height))
            let toPoint = CGPoint(x: noteX(to.fret, in: width), y: rowY(to.string, in: height))
            // A slide is a real move along one string, so it keeps its arrowhead and reads brighter;
            // an ordinary jump between notes is just a faint direction hint.
            let isSlide = to.technique == .slide && from.string == to.string
            Group {
                if isSlide {
                    SlideCue(fromX: fromPoint.x, toX: toPoint.x, midY: toPoint.y)
                        .stroke(tint.opacity(0.95),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                } else if from.string == to.string, let technique = to.technique,
                          LegatoCue.letter(for: technique) != nil {
                    // A hammer-on or pull-off (ADR 0251) is a move along one string too: its curve and letter.
                    LegatoCue(technique: technique, fromX: fromPoint.x, toX: toPoint.x, stringY: toPoint.y,
                              tint: tint)
                } else if showsMoves {
                    MoveArrow(from: fromPoint, fromRadius: dotDiameter(isActive: false, isRoot: isRoot(from)) / 2,
                              to: toPoint, toRadius: dotDiameter(isActive: true, isRoot: isRoot(to)) / 2)
                        .stroke(tint.opacity(0.9),
                                style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
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
    ///
    /// A board that plays chords (a Triads run, ADR 0313) reads against **the chord under the hand**: its
    /// notes wear its colour (ADR 0308 D7), the note being played filled with it, and only its own root is
    /// ringed, with interval labels counted from it. Played Together, all three are lit at once (D8), and
    /// the notes of the shape before that moved are ringed dashed: where the fingers just were.
    private func notes(width: CGFloat, height: CGFloat) -> some View {
        let active = activeIndex.flatMap { drill.note(at: $0) }
        let chord = drill.chordIndex(at: activeIndex)
        let justLeft = drill.notesJustLeft(chord: chord)
        let chordColour = chord.flatMap { drill.chords?[$0].numeral }.map { PocketColor.chord(degree: $0.degree) }
        let readingRoot = drill.readingRoot(chord: chord)
        // One dot per distinct **position**, not per played slot: a sequenced run sounds the same fret
        // several times, and a dot per slot stacked its own translucency into a solid white blob while
        // the least-repeated notes stayed grey (see `FretboardDrill.plottedPositions`).
        return ForEach(drill.plottedPositions, id: \.note) { entry in
            if isVisible(entry.note) {
                let isActive = activeIndex.map { entry.indices.contains($0) } ?? false
                let isRoot = drill.ringsRoot(entry.note, slots: entry.indices, chord: chord)
                let shade = drill.isPlayed(byChord: chord, slots: entry.indices) ? chordColour ?? tint : nil
                let diameter = dotDiameter(isActive: isActive, isRoot: isRoot)
                let focus = passFocusOpacity(noteIndices: entry.indices)
                Circle()
                    .fill(fill(isActive: isActive, isRoot: isRoot, chord: shade))
                    .frame(width: diameter, height: diameter)
                    .overlay(rootRing(isRoot: isRoot, isActive: isActive, chord: shade))
                    .overlay(noteLabel(entry.note, isActive: isActive, isRoot: isRoot, chord: shade,
                                       root: readingRoot))
                    .background(JustLeftRing(isShown: justLeft.contains(entry.note), dotDiameter: diameter))
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

    /// Dot size — enlarged when captions are on so a "♭7" fits, and enlarged again when lit.
    private func dotDiameter(isActive: Bool, isRoot: Bool) -> CGFloat {
        let hasLabel = labelMode != .none
        if isActive { return hasLabel ? 21 : 18 }
        return hasLabel ? 18 : (isRoot ? 13 : 12)
    }

    /// The dot fill. A root reads as a **hollow amber ring** at rest (board-coloured centre so the
    /// amber `rootRing` stroke shows) and a **solid amber** dot when it lights; a non-root lights in
    /// the tint and rests as a faint ink dot. Captioned idle dots fill a touch stronger so the text
    /// sits on a legible chip. A note of the chord under the hand wears the chord's colour instead.
    private func fill(isActive: Bool, isRoot: Bool, chord: Color?) -> Color {
        if let chord { return isActive ? chord : chord.opacity(0.55) }
        if isRoot { return isActive ? PocketColor.marker : PocketColor.background }
        if isActive { return tint }
        return PocketColor.textPrimary.opacity(labelMode == .none ? 0.22 : 0.32)
    }

    /// The note's caption (note name or interval), coloured to read on its dot. Absent in `.none`
    /// mode and for interval mode on a rootless drill.
    @ViewBuilder
    private func noteLabel(_ note: FretNote, isActive: Bool, isRoot: Bool, chord: Color?, root: Int?) -> some View {
        if let text = label(for: note, root: root) {
            Text(text)
                .font(.system(size: 9, weight: .bold))
                .minimumScaleFactor(0.6)
                .lineLimit(1)
                .foregroundStyle(labelColor(isActive: isActive, isRoot: isRoot, chord: chord))
        }
    }

    /// Text colour: dark ink on a lit (bright-filled) dot, amber on an idle root ring, faint-dot ink
    /// otherwise. On a chord's colour, its own ink when filled (ADR 0308 D7), the board's ink when tinted.
    private func labelColor(isActive: Bool, isRoot: Bool, chord: Color?) -> Color {
        if chord != nil { return isActive ? PocketColor.chordInk : PocketColor.textPrimary }
        if isActive { return PocketColor.background }
        if isRoot { return PocketColor.marker }
        return PocketColor.textPrimary
    }

    /// The caption string for a note in the current mode, or `nil` when nothing should show. Intervals
    /// count from `root`: the drill's, or the root of the chord under the hand.
    private func label(for note: FretNote, root: Int?) -> String? {
        let pitchClass = drill.pitchClass(of: note)
        switch labelMode {
        case .none: return nil
        case .note: return spelling.name(pitchClass: pitchClass)
        case .interval:
            guard let root else { return nil }
            return Self.intervalNames[(((pitchClass - root) % 12) + 12) % 12]
        }
    }

    /// Scale-degree names for the twelve semitones above the root (sharp-side spelling, matching the
    /// app's sharp fretboard): R, ♭2, 2, ♭3, 3, 4, ♭5, 5, ♭6, 6, ♭7, 7.
    private static let intervalNames =
        ["R", "♭2", "2", "♭3", "3", "4", "♭5", "5", "♭6", "6", "♭7", "7"]

    /// A thin halo around a root so it separates from neighbours even where notes share a cell. The other
    /// notes of the chord under the hand take a halo in its colour, so the three read as one shape.
    @ViewBuilder
    private func rootRing(isRoot: Bool, isActive: Bool, chord: Color?) -> some View {
        if isRoot {
            Circle().strokeBorder(PocketColor.marker, lineWidth: isActive ? 2 : 1.5)
        } else if let chord, !isActive {
            Circle().strokeBorder(chord, lineWidth: 1.5)
        }
    }

    /// Whether a note sounds the drill's root pitch class (only when the drill names one) — resolved in
    /// the drill's own tuning so a bass root ring lands correctly (ADR 0116 S5).
    func isRoot(_ note: FretNote) -> Bool {
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

}
