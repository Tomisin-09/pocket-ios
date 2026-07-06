import SwiftUI

/// The stopped-state **template previews** on the exercise run screen (ADR 0065): a titled card that
/// shows what the exercise plays before you press Start — the strum lane (static, so you read the
/// down/up directions), the fretboard drill (self-driving animation, so the shape walks the neck), the
/// chord sequence, or (Strum & Chords) both the lane and the sequence together. Plus the **running**
/// counterpart, `ExerciseTemplateSurface`, below. Split out of `ExerciseRunView` to keep that file lean.

/// A static strum-pattern card.
struct StrumPatternPreview: View {
    let pattern: StrumPattern

    var body: some View {
        templatePreviewCard("Strum pattern") {
            StrumLane(pattern: pattern, tint: PocketColor.practice)
        }
    }
}

/// An animated fretboard-drill card, captioned per the global note-label preference so it matches the
/// creation preview and the live board.
struct FretboardExercisePreview: View {
    let drill: FretboardDrill
    @AppStorage("fretboardLabelMode") private var storedLabelMode = FretLabelMode.none.rawValue
    private var labelMode: FretLabelMode { FretLabelMode(rawValue: storedLabelMode) ?? .none }

    var body: some View {
        templatePreviewCard("Fretboard") {
            FretboardDrillPreview(drill: drill, tint: PocketColor.practice, labelMode: labelMode)
        }
    }
}

/// A static chord-progression card: the sequence of chord diagrams the drill changes through, so you
/// read the whole progression before you press Start. The first chord shows active; the rest preview.
struct ChordProgressionPreview: View {
    let progression: ChordProgression

    var body: some View {
        templatePreviewCard("Chord progression") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(Array(progression.changes.enumerated()), id: \.offset) { index, change in
                        ChordDiagramView(voicing: change.voicing, isActive: index == 0,
                                         tint: PocketColor.practice,
                                         degreeLabel: progression.numeral(for: change.voicing))
                            .frame(width: 78)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(height: 120)
        }
    }
}

/// A static strum-groove-over-chords card: the strum lane above the chord sequence it plays over, so
/// you read both before you press Start. The first chord shows active; the rest preview.
struct StrumChordsPreview: View {
    let sheet: StrumChordSheet

    var body: some View {
        templatePreviewCard("Strum & chords") {
            VStack(alignment: .leading, spacing: 10) {
                StrumLane(pattern: sheet.strumPattern, tint: PocketColor.practice)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(Array(sheet.chordProgression.changes.enumerated()),
                                id: \.offset) { index, change in
                            ChordDiagramView(voicing: change.voicing, isActive: index == 0,
                                             tint: PocketColor.practice,
                                             degreeLabel: sheet.chordProgression.numeral(for: change.voicing))
                                .frame(width: 78)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 120)
            }
        }
    }
}

/// The **running-state** template surface (ADR 0065 T5): picks the renderer by `exercise.kind`; a
/// missing/undecodable payload or unrecognised kind falls back to the metronome beat dots — the
/// universal underlay (T1).
///
/// The **fretboard** surface is shown *throughout*, count-in included — it sits static (fully
/// plotted, nothing lit) until the first post-count-in downbeat, then walks (`FretboardView` anchors
/// its own walk to the count-in clearing). This is the fix for the board **disappearing during the
/// count and popping back** when the music starts: now it's simply present the whole time, and only
/// the walk begins — one bar in, on the first real beat.
///
/// The strum and chord surfaces still engage once the count-in clears, cross-dissolving from the beat
/// dots: swapping a different concrete view type is a hard cut in a plain container (leaving/entering
/// views share one layout slot with no overlap), so they live in a `ZStack` where `.transition`
/// makes them briefly coexist and fade. (Extending the always-present treatment to those is a
/// follow-up — they'd each need the same count-in-clearing walk anchor.)
struct ExerciseTemplateSurface: View {
    let engine: StandaloneMetronomeEngine
    let exercise: Exercise
    var labelMode: FretLabelMode = .none

    /// True once the count-in has cleared — the boolean the strum/chord fade animates on.
    private var running: Bool { engine.automatorCountdown == nil }

    var body: some View {
        ZStack {
            if exercise.kind == .fretboard, let drill = exercise.fretboardDrill {
                // Not gated on the count-in: the board is present (static) through it and walks after.
                FretboardView(engine: engine, drill: drill, tint: PocketColor.practice,
                             labelMode: labelMode)
            } else if exercise.kind == .strumming, let pattern = exercise.strumPattern, running {
                StrummingLaneView(engine: engine, pattern: pattern, tint: PocketColor.practice)
                    .transition(.opacity)
            } else if exercise.kind == .chords, let progression = exercise.chordProgression, running {
                ChordChangeView(engine: engine, progression: progression, tint: PocketColor.practice)
                    .transition(.opacity)
            } else if exercise.kind == .strumChords, let sheet = exercise.strumChordSheet, running {
                StrumChordsView(engine: engine, sheet: sheet, tint: PocketColor.practice)
                    .transition(.opacity)
            } else {
                BeatIndicator(engine: engine, tint: PocketColor.practice)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: running)
    }
}

/// A titled, rounded card every preview shares.
@ViewBuilder
private func templatePreviewCard<Content: View>(_ title: String,
                                                @ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 8) {
        Text(title)
            .font(.futura(.caption, weight: .semibold))
            .foregroundStyle(PocketColor.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
        content()
    }
    .padding(14)
    .background(RoundedRectangle(cornerRadius: 14).fill(PocketColor.surfaceSubtle))
}
