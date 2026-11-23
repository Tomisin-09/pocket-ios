import SwiftUI

/// A **self-driving preview** of a drill (ADR 0065 build 2, generative authoring): walks the board on
/// its own internal clock at a fixed `bpm`, with no metronome engine — so an authoring editor can show
/// "watch it before you save" the moment the shape changes. A thin skin over `FretboardGrid`, reading
/// a continuous beat position measured from **this view's own appearance**, not raw wall-clock time —
/// reading `Date.timeIntervalSinceReferenceDate` directly would enter the free-running walk at
/// whichever phase the absolute clock happened to be at, sometimes mid-shape on the high e instead of
/// note 0, the low E root. Anchoring to appearance guarantees the walk always visibly starts there,
/// the same guarantee the one-shot `playOnceOrigin` path already gave.
struct FretboardDrillPreview: View {
    let drill: FretboardDrill
    /// A gentle **preview tempo** — slower than any real practice pace so the shape is easy to follow
    /// at a glance. The live practice board is engine-driven and plays at the actual exercise tempo.
    static let previewBPM = 60
    var bpm: Int = FretboardDrillPreview.previewBPM
    var tint: Color = PocketColor.practice
    var labelMode: FretLabelMode = .none
    /// Set (to a fresh `Date()`) by a `FretboardPlayOnceButton` to request a single walk-through,
    /// independent of the global animate preference — a deliberate, user-requested pass rather than
    /// sustained motion, so it plays even under Reduce Motion (ADR 0065). `nil` requests nothing.
    var playOnceToken: Date?
    /// On by default (ADR 0157) and forced off under Reduce Motion; off shows a static,
    /// fully-plotted board unless a one-shot play is in progress.
    @AppStorage(AppSettings.Key.exerciseAnimates) private var animates = AppSettings.exerciseAnimatesDefault
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPlayingOnce = false
    @State private var playOnceOrigin: Date?
    /// The moment this preview appeared — the origin the free-running walk measures from (below).
    @State private var appearedAt: Date?
    /// For a board that plays chords (ADR 0313): where the chord under the hand goes. `nil` puts
    /// `DrillChordLine` over the board; a binding reports the chord instead, for an editor that names it in
    /// a row of its own, beside Display.
    var playingChord: Binding<Int?>?

    private var isAnimating: Bool { (animates && !reduceMotion) || isPlayingOnce }

    var body: some View {
        Group {
            if isAnimating {
                TimelineView(.animation) { context in
                    board(activeIndex: activeIndex(at: context.date))
                }
            } else {
                board(activeIndex: nil)
            }
        }
        .onAppear { if appearedAt == nil { appearedAt = .now } }
        .task(id: playOnceToken) {
            guard let playOnceToken else { return }
            playOnceOrigin = playOnceToken
            isPlayingOnce = true
            let seconds = drill.lengthInBeats * 60.0 / Double(max(1, bpm))
            try? await Task.sleep(for: .seconds(max(0.1, seconds)))
            isPlayingOnce = false
        }
    }

    /// The grid, with the chord under the hand named over it or reported, when the drill plays chords.
    @ViewBuilder private func board(activeIndex: Int?) -> some View {
        let grid = FretboardGrid(drill: drill, activeIndex: activeIndex, tint: tint, labelMode: labelMode)
        if drill.chords == nil {
            grid
        } else if let playingChord {
            grid.onChange(of: drill.chordIndex(at: activeIndex), initial: true) { _, now in
                playingChord.wrappedValue = now
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                DrillChordLine(drill: drill, chord: drill.chordIndex(at: activeIndex))
                grid
            }
        }
    }

    /// The active note at `now`. During a one-shot play it's measured from the play's own origin;
    /// otherwise it free-runs from this view's own appearance — both guarantee note 0 (the lowest
    /// note) at the start rather than an arbitrary wall-clock phase. Empty drills return `nil`.
    private func activeIndex(at now: Date) -> Int? {
        guard drill.noteCount > 0 else { return nil }
        if isPlayingOnce, let playOnceOrigin {
            let beats = now.timeIntervalSince(playOnceOrigin) * Double(max(1, bpm)) / 60.0
            return drill.activeNoteIndex(atBeat: beats)
        }
        let origin = appearedAt ?? now
        let beats = now.timeIntervalSince(origin) * Double(max(1, bpm)) / 60.0
        return drill.activeNoteIndex(atBeat: beats)
    }
}

#Preview("Fretboard drill preview") {
    FretboardDrillPreview(drill: .spiderWalk)
        .padding()
        .background(PocketColor.background)
        .preferredColorScheme(.dark)
}
