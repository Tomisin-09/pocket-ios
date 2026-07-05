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
struct FretboardGrid: View {
    let drill: FretboardDrill
    /// The note lit now, or `nil` for a static (nothing-lit) read.
    var activeIndex: Int?
    var tint: Color = PocketColor.practice

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

    /// The board itself: string lines, fret separators + nut, and the plotted / active note dots.
    private var board: some View {
        GeometryReader { geo in
            let width = geo.size.width, height = geo.size.height
            ZStack {
                stringLines(width: width, height: height)
                fretSeparators(width: width, height: height)
                nut(height: height)
                notes(width: width, height: height)
            }
        }
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

    /// Every note the drill uses, plotted faintly; the active one lit and enlarged in the tint.
    private func notes(width: CGFloat, height: CGFloat) -> some View {
        let active = activeIndex.flatMap { drill.note(at: $0) }
        return ForEach(Array(drill.notes.enumerated()), id: \.offset) { index, note in
            if let note {
                let isActive = index == activeIndex
                Circle()
                    .fill(isActive ? tint : PocketColor.textPrimary.opacity(0.22))
                    .frame(width: isActive ? 18 : 12, height: isActive ? 18 : 12)
                    .position(x: noteX(note.fret, in: width), y: rowY(note.string, in: height))
                    .animation(.easeOut(duration: 0.07), value: isActive)
            }
        }
        // Keep the enlarged active dot on top even where notes share a cell.
        .zIndex(active == nil ? 0 : 1)
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
            return "\(name) \(position)\(how)"
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

    /// Wall-clock moment `engine.currentBeat` last advanced — the anchor the sub-beat fraction is
    /// measured from.
    @State private var beatOnset = Date.now
    /// The beat index that onset belongs to, so a re-render mid-beat keeps the same anchor.
    @State private var anchoredBeat = -1

    var body: some View {
        TimelineView(.animation) { context in
            FretboardGrid(drill: drill, activeIndex: activeNote(at: context.date), tint: tint)
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
    var bpm: Int = 96
    var tint: Color = PocketColor.practice

    var body: some View {
        TimelineView(.animation) { context in
            FretboardGrid(drill: drill, activeIndex: activeIndex(at: context.date), tint: tint)
        }
    }

    /// The active note at `now`, from a free-running clock: beats elapsed = seconds × bpm/60. Empty
    /// drills return `nil` (nothing lit), handled by `activeNoteIndex`.
    private func activeIndex(at now: Date) -> Int? {
        guard drill.noteCount > 0 else { return nil }
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
