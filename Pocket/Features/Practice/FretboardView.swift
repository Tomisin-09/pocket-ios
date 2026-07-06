import SwiftUI

/// The **presentational fretboard** (ADR 0065 build 2): a string × fret grid with the drill's notes
/// plotted faintly and an optional `activeIndex` lit as the run walks the board. Holds no timing
/// logic — the caller decides which note is active (the live `FretboardView` computes it from the
/// clock; a static read passes `nil`). Reused so any preview and the running board are identical.
///
/// **T10** — every colour resolves through a semantic `PocketColor` role: the strings and fret
/// separators via the grid-line role, the nut and labels via the ink roles, plotted notes a dimmed
/// ink, and the active note in the content `tint` — so the board reskins under light/dark and any
/// future theme.
/// How each fretboard note is captioned (ADR 0065 build 2). A viewing preference the player toggles —
/// note names, scale-degree intervals, or nothing — persisted globally so the creation preview and
/// the live practice board agree. Intervals need a tonal centre (`FretboardDrill.rootPitchClass`); a
/// rootless drill (a spider walk) shows nothing in interval mode.
enum FretLabelMode: String, CaseIterable, Identifiable {
    case none, note, interval
    var id: String { rawValue }

    /// The control's short label for each mode.
    var pickerLabel: String {
        switch self {
        case .none: return "Off"
        case .note: return "Note"
        case .interval: return "Interval"
        }
    }
}

struct FretboardGrid: View {
    let drill: FretboardDrill
    /// The note lit now, or `nil` for a static (nothing-lit) read.
    var activeIndex: Int?
    var tint: Color = PocketColor.practice
    /// How to caption each note (note name / interval / nothing).
    var labelMode: FretLabelMode = .none

    private var stringCount: Int { max(1, drill.stringCount) }
    private var span: Int { max(1, drill.displayFretSpan) }
    private var lowestFret: Int { drill.displayLowestFret }

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
            if let note {
                let isActive = index == activeIndex
                let isRoot = isRoot(note)
                let diameter = dotDiameter(isActive: isActive, isRoot: isRoot)
                Circle()
                    .fill(fill(isActive: isActive, isRoot: isRoot))
                    .frame(width: diameter, height: diameter)
                    .overlay(rootRing(isRoot: isRoot, isActive: isActive))
                    .overlay(noteLabel(note, isActive: isActive, isRoot: isRoot))
                    .position(x: noteX(note.fret, in: width), y: rowY(note.string, in: height))
                    .animation(.easeOut(duration: 0.07), value: isActive)
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
/// interpolation the strum lane uses. Before beat 0 (the count-in) and while paused nothing lights,
/// which is what the pure math returns.
struct FretboardView: View {
    let engine: StandaloneMetronomeEngine
    let drill: FretboardDrill
    var tint: Color = PocketColor.practice
    var labelMode: FretLabelMode = .none

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
    }

    /// The continuous beat position at `now`, then the drill's active note for it. Returns `nil`
    /// before beat 0 and for an empty drill — both handled by `activeNoteIndex`.
    private func activeNote(at now: Date) -> Int? {
        let secondsPerBeat = 60.0 / Double(max(1, engine.bpm))
        let fraction = engine.isPlaying
            ? min(1, max(0, now.timeIntervalSince(beatOnset) / secondsPerBeat))
            : 0
        let beatPosition = Double(anchoredBeat) + fraction
        return drill.activeNoteIndex(atBeat: beatPosition)
    }
}

/// A **self-driving preview** of a drill (ADR 0065 build 2, generative authoring): walks the board on
/// its own internal clock at a fixed `bpm`, with no metronome engine — so an authoring editor can show
/// "watch it before you save" the moment the shape changes. A thin skin over `FretboardGrid`, reading
/// a continuous beat position straight from wall-clock time; nothing to start or stop.
struct FretboardDrillPreview: View {
    let drill: FretboardDrill
    /// A gentle **preview tempo** — slower than any real practice pace so the shape is easy to follow
    /// at a glance. The live practice board is engine-driven and plays at the actual exercise tempo.
    var bpm: Int = 60
    var tint: Color = PocketColor.practice
    var labelMode: FretLabelMode = .none
    /// Set (to a fresh `Date()`) by a `FretboardPlayOnceButton` to request a single walk-through,
    /// independent of the global animate preference — a deliberate, user-requested pass rather than
    /// sustained motion, so it plays even under Reduce Motion (ADR 0065). `nil` requests nothing.
    var playOnceToken: Date?
    /// Off by default (photosensitivity precaution) and forced off under Reduce Motion; off shows a
    /// static, fully-plotted board unless a one-shot play is in progress.
    @AppStorage(AppSettings.Key.exerciseAnimates) private var animates = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPlayingOnce = false
    @State private var playOnceOrigin: Date?

    private var isAnimating: Bool { (animates && !reduceMotion) || isPlayingOnce }

    var body: some View {
        Group {
            if isAnimating {
                TimelineView(.animation) { context in
                    FretboardGrid(drill: drill, activeIndex: activeIndex(at: context.date),
                                  tint: tint, labelMode: labelMode)
                }
            } else {
                FretboardGrid(drill: drill, activeIndex: nil, tint: tint, labelMode: labelMode)
            }
        }
        .task(id: playOnceToken) {
            guard let playOnceToken else { return }
            playOnceOrigin = playOnceToken
            isPlayingOnce = true
            let seconds = drill.lengthInBeats * 60.0 / Double(max(1, bpm))
            try? await Task.sleep(for: .seconds(max(0.1, seconds)))
            isPlayingOnce = false
        }
    }

    /// The active note at `now`. During a one-shot play it's measured from the play's own origin (so
    /// it always starts the shape from note 0); otherwise it free-runs from wall-clock time (beats
    /// elapsed = seconds × bpm/60). Empty drills return `nil` (nothing lit).
    private func activeIndex(at now: Date) -> Int? {
        guard drill.noteCount > 0 else { return nil }
        if isPlayingOnce, let playOnceOrigin {
            let beats = now.timeIntervalSince(playOnceOrigin) * Double(max(1, bpm)) / 60.0
            return drill.activeNoteIndex(atBeat: beats)
        }
        let beats = now.timeIntervalSinceReferenceDate * Double(max(1, bpm)) / 60.0
        return drill.activeNoteIndex(atBeat: beats)
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
