import SwiftUI

/// The **live strum-and-chords surface** (ADR 0065): the chord-changing view stacked over the
/// strumming lane, both driven off **one shared beat origin** — the beat this surface first mounts,
/// which is the first musical downbeat since the run screen only mounts it once `automatorCountdown`
/// clears (the exact anchor `ChordChangeView` captures, reused here so a chord's hold and the strum
/// pattern's wrap both measure from the same zero rather than the engine's absolute `currentBeat`,
/// which counts through the count-in).
///
/// The two surfaces stay **independent** past that shared anchor: the chord progression advances on
/// its own `lengthInBeats`, the strum pattern wraps on its own — there is no reset that restarts the
/// groove on a chord change. That would need impure, stateful bookkeeping neither pure timing model
/// carries today; instead a sheet whose groove length divides evenly into its per-chord hold (like
/// the shipped `.popGroove`) simply *reads* as locked, by construction, without the surfaces knowing
/// about each other.
///
/// Only the strum lane is gated by the `exerciseAnimates` preference (and Reduce Motion) — mirroring
/// `StrummingLaneView`. The chord surface is never gated, mirroring `ChordChangeView`: a per-bar
/// change is content, not flashing decoration.
struct StrumChordsView: View {
    let engine: StandaloneMetronomeEngine
    let sheet: StrumChordSheet
    var tint: Color = PocketColor.practice

    /// The engine beat at which this surface began (the first post-count-in downbeat), captured once
    /// — shared by both the chord and strum timing below.
    @State private var originBeat: Int?
    /// Wall-clock moment `engine.currentBeat` last advanced — the anchor the strum lane's sub-beat
    /// fraction is measured from (the chord surface only needs whole-beat granularity).
    @State private var beatOnset = Date.now
    /// The beat index that onset belongs to, so a re-render mid-beat keeps the same anchor.
    @State private var anchoredBeat = -1
    @AppStorage(AppSettings.Key.exerciseAnimates) private var animates = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The active chord index, measured from the anchored origin, or `nil` before it's anchored.
    private var activeChordIndex: Int? {
        guard let origin = originBeat else { return nil }
        return sheet.chordProgression.activeIndex(atBeat: Double(engine.currentBeat - origin))
    }

    var body: some View {
        VStack(spacing: 18) {
            chordSurface
            strumSurface
        }
        .onChange(of: engine.currentBeat) { _, newValue in
            anchoredBeat = newValue
            beatOnset = .now
        }
        .onAppear { if originBeat == nil { originBeat = max(0, engine.currentBeat) } }
        .accessibilityElement(children: .contain)
    }

    // MARK: - Chord surface (borrows `ChordChangeView`'s layout, sharing this view's origin)

    @ViewBuilder
    private var chordSurface: some View {
        let index = activeChordIndex ?? 0
        let progression = sheet.chordProgression
        let current = progression.change(at: index)?.voicing
        let next = progression.nextIndex(after: index).flatMap { progression.change(at: $0)?.voicing }
        let isRunning = activeChordIndex != nil

        HStack(alignment: .top, spacing: 24) {
            if let current {
                ChordDiagramView(voicing: current, isActive: isRunning, tint: tint,
                                 degreeLabel: progression.numeral(for: current))
                    .frame(maxWidth: 190)
                    .animation(.easeInOut(duration: 0.15), value: current)
            }
            if let next {
                VStack(spacing: 6) {
                    Text(isRunning ? "Next" : "Get ready")
                        .font(.futura(.caption, weight: .semibold))
                        .foregroundStyle(PocketColor.textSecondary)
                    ChordDiagramView(voicing: next, isActive: false, tint: tint,
                                     degreeLabel: progression.numeral(for: next))
                        .frame(maxWidth: 120)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .animation(.easeInOut(duration: 0.15), value: index)
    }

    // MARK: - Strum surface (borrows `StrummingLaneView`'s sub-beat interpolation, same origin)

    @ViewBuilder
    private var strumSurface: some View {
        if animates && !reduceMotion {
            TimelineView(.animation) { context in
                StrumLane(pattern: sheet.strumPattern, activeIndex: activeSlot(at: context.date), tint: tint)
            }
        } else {
            StrumLane(pattern: sheet.strumPattern, activeIndex: nil, tint: tint)
        }
    }

    /// The continuous beat position at `now` relative to the shared origin, then the strum pattern's
    /// active slot for it. `nil` before the origin is anchored — `activeSlotIndex` handles the rest.
    private func activeSlot(at now: Date) -> Int? {
        guard let origin = originBeat else { return nil }
        let secondsPerBeat = 60.0 / Double(max(1, engine.bpm))
        let fraction = engine.isPlaying
            ? min(1, max(0, now.timeIntervalSince(beatOnset) / secondsPerBeat))
            : 0
        let beatPosition = Double(anchoredBeat - origin) + fraction
        return sheet.strumPattern.activeSlotIndex(atBeat: beatPosition)
    }
}

#Preview("Strum & chords") {
    StrumChordsView(engine: StandaloneMetronomeEngine(), sheet: .popGroove)
        .padding()
        .background(PocketColor.background)
        .preferredColorScheme(.dark)
}
