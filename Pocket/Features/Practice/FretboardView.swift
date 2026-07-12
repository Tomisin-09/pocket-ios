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

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            stringLabels
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
        .frame(width: 16)
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
                notes(width: width, height: height)
            }
        }
    }

    /// The standard guitar position markers (single dot at 3·5·7·9·15·17·19·21, double at 12·24) that
    /// fall within the visible fret window — a faint orientation cue, same as the wood inlays on a
    /// real neck, so "which position is this" reads at a glance without counting fret lines.
    private static let singleInlayFrets: Set<Int> = [3, 5, 7, 9, 15, 17, 19, 21]
    private static let doubleInlayFrets: Set<Int> = [12, 24]

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

    /// The slide-teaching cues (ADR 0083 S8): for every note that slides in on the **same string**
    /// from the one before it, a static arrow from the departed fret to the landed fret. Brightened
    /// while its target note is active so the walk and the arrow read together; always drawn, so it
    /// is the static "slide" badge when motion is off.
    private func slideCues(width: CGFloat, height: CGFloat) -> some View {
        ForEach(Array(drill.notes.enumerated()), id: \.offset) { index, note in
            if let note, note.technique == .slide, index > 0, isVisible(note),
               let previous = drill.notes[index - 1], previous.string == note.string {
                SlideCue(fromX: noteX(previous.fret, in: width),
                         toX: noteX(note.fret, in: width),
                         midY: rowY(note.string, in: height))
                    .stroke(tint.opacity(index == activeIndex ? 0.95 : 0.55),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
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
        return ForEach(Array(drill.notes.enumerated()), id: \.offset) { index, note in
            if let note, isVisible(note) {
                let isActive = index == activeIndex
                let isRoot = isRoot(note)
                let diameter = dotDiameter(isActive: isActive, isRoot: isRoot)
                let focus = passFocusOpacity(noteIndex: index)
                Circle()
                    .fill(fill(isActive: isActive, isRoot: isRoot))
                    .frame(width: diameter, height: diameter)
                    .overlay(rootRing(isRoot: isRoot, isActive: isActive))
                    .overlay(noteLabel(note, isActive: isActive, isRoot: isRoot))
                    .opacity(focus)
                    .position(x: noteX(note.fret, in: width), y: rowY(note.string, in: height))
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

    /// The opacity for a note under **pass focus** (ADR 0083 S2b): while a multi-pass run walks, notes
    /// outside the active note's pass drop to a ghost so the eye locks onto the position being played;
    /// the active pass, a single-pass run, and the static board (no `activeIndex`) render fully. The
    /// reusable substrate slice 3's box focus will read the same way.
    private func passFocusOpacity(noteIndex: Int) -> Double {
        guard isMultiPass, let activeIndex, let groups = drill.noteGroups,
              groups.indices.contains(noteIndex), groups.indices.contains(activeIndex)
        else { return 1 }
        return groups[noteIndex] == groups[activeIndex] ? 1 : Self.offPassGhostOpacity
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
        let pitchClass = GuitarScale.pitchClass(string: note.string, fret: note.fret)
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

    /// Whether a note sounds the drill's root pitch class (only when the drill names one).
    private func isRoot(_ note: FretNote) -> Bool {
        guard let root = drill.rootPitchClass else { return false }
        return GuitarScale.pitchClass(string: note.string, fret: note.fret) == root
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
        .frame(height: 12)
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
        let standard = ["e", "B", "G", "D", "A", "E"]
        if count == standard.count, standard.indices.contains(index) { return standard[index] }
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

/// The **live** fretboard over the shared metronome clock (ADR 0065 T3/T5): a thin skin over
/// `FretboardGrid` that reconstructs a continuous beat position from the engine's per-beat
/// `currentBeat` and asks the pure `FretboardDrill` which note is active — the identical clock
/// interpolation the strum lane uses.
///
/// **Shown throughout the count-in (static), with the walk anchored to the count-in *clearing*.**
/// The board sits fully plotted but with nothing lit during the count-in, so it doesn't vanish for
/// the count and pop back when the music starts — only the walk begins, one bar in. A run's note
/// count isn't meter-bound (unlike a strum pattern, always re-gridded to exactly one bar), so its
/// cycle rarely divides evenly into the count-in — measuring from the engine's raw absolute beat
/// would start the walk mid-shape (sometimes on the high e instead of the low E root). Capturing
/// `currentBeat` the instant `automatorCountdown` clears — the first musical downbeat, mirroring
/// `ChordChangeView`'s origin — and measuring from there guarantees note 0 (always the lowest-pitched
/// note in the generated box, `CAGEDShape`) lands exactly on that downbeat. While paused, or before
/// the origin is anchored, nothing lights.
struct FretboardView: View {
    let engine: StandaloneMetronomeEngine
    let drill: FretboardDrill
    var tint: Color = PocketColor.practice
    var labelMode: FretLabelMode = .none

    /// The engine beat the walk measures from — the first beat after the count-in clears. `nil`
    /// through the count-in, which is what keeps the board static until the music actually starts.
    @State private var originBeat: Int?
    /// Wall-clock moment `engine.currentBeat` last advanced — the anchor the sub-beat fraction is
    /// measured from.
    @State private var beatOnset = Date.now
    /// The beat index that onset belongs to, so a re-render mid-beat keeps the same anchor.
    @State private var anchoredBeat = -1
    /// The walking-highlight preference — **off by default** as a photosensitivity precaution, and
    /// forced off under the system Reduce Motion setting. Off shows a static, fully-plotted board.
    @AppStorage(AppSettings.Key.exerciseAnimates) private var animates = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if animates && !reduceMotion {
                TimelineView(.animation) { context in
                    FretboardGrid(drill: drill, activeIndex: activeNote(at: context.date),
                                  tint: tint, labelMode: labelMode)
                }
            } else {
                FretboardGrid(drill: drill, activeIndex: nil, tint: tint, labelMode: labelMode)
            }
        }
        .onChange(of: engine.currentBeat) { _, newValue in
            anchoredBeat = newValue
            beatOnset = .now
        }
        .onChange(of: engine.automatorCountdown) { _, countdown in
            // The count-in just cleared → this beat is the first musical downbeat; pin note 0 to it.
            if countdown == nil { anchorToDownbeat() }
        }
        .onAppear {
            // Mounted with no count-in pending (count-in disabled, or resuming an already-counted-in
            // run) → anchor now. Otherwise wait for the count-in to clear, above.
            if engine.automatorCountdown == nil { anchorToDownbeat() }
        }
    }

    /// Pin the walk's origin to the current beat. Called the instant the count-in clears (or on
    /// appear when there is none), so note 0 lands on the first musical downbeat; the board stays
    /// static (nothing lit) through the count-in before it, since `activeNote` returns `nil` until
    /// this runs.
    private func anchorToDownbeat() {
        guard originBeat == nil else { return }
        let beat = max(0, engine.currentBeat)   // guard the pre-first-beat -1 in the no-count-in path
        originBeat = beat
        anchoredBeat = beat
        beatOnset = .now
    }

    /// The continuous beat position at `now` relative to the anchored origin, then the drill's
    /// active note for it. `nil` before the origin is anchored — `activeNoteIndex` handles the rest.
    private func activeNote(at now: Date) -> Int? {
        guard let originBeat else { return nil }
        let secondsPerBeat = 60.0 / Double(max(1, engine.bpm))
        let fraction = engine.isPlaying
            ? min(1, max(0, now.timeIntervalSince(beatOnset) / secondsPerBeat))
            : 0
        let beatPosition = Double(anchoredBeat - originBeat) + fraction
        return drill.activeNoteIndex(atBeat: beatPosition)
    }
}

#Preview("Fretboard") {
    VStack(spacing: 24) {
        FretboardGrid(drill: .spiderWalk, activeIndex: 2)
        FretboardView(engine: StandaloneMetronomeEngine(), drill: .spiderWalk)
    }
    .padding()
    .background(PocketColor.background)
    .preferredColorScheme(.dark)
}
