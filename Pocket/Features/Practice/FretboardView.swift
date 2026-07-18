import SwiftUI

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
