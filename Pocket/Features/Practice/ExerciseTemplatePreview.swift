import SwiftUI

/// The stopped-state **template previews** on the exercise run screen (ADR 0065): a titled card that
/// shows what the exercise plays before you press Start — the strum lane (static, so you read the
/// down/up directions), the fretboard drill (self-driving animation, so the shape walks the neck), the
/// chord sequence, or (Strum & Chords) both the lane and the sequence together. Plus the **running**
/// counterpart, `ExerciseTemplateSurface`, below. Split out of `ExerciseRunView` to keep that file lean.

/// A static strum-pattern card.
struct StrumPatternPreview: View {
    let pattern: StrumPattern
    /// Optional "Edit shape" action, tucked into the card header (ADR 0077). Passed only from the
    /// library run screen; `nil` in a routine preview, where an exercise is read-only.
    var editShape: (() -> Void)?

    var body: some View {
        templatePreviewCard("Strum pattern", editShape: editShape) {
            StrumLane(pattern: pattern, tint: PocketColor.practice)
        }
    }
}

/// An animated fretboard-drill card, captioned per the global note-label preference so it matches the
/// creation preview and the live board.
struct FretboardExercisePreview: View {
    let drill: FretboardDrill
    var editShape: (() -> Void)?
    @AppStorage("fretboardLabelMode") private var storedLabelMode = FretLabelMode.none.rawValue
    private var labelMode: FretLabelMode { FretLabelMode(rawValue: storedLabelMode) ?? .none }

    var body: some View {
        templatePreviewCard("Fretboard", editShape: editShape) {
            FretboardDrillPreview(drill: drill, tint: PocketColor.practice, labelMode: labelMode)
        }
    }
}

/// A static chord-progression card: the sequence of chord diagrams the drill changes through, so you
/// read the whole progression before you press Start. The first chord shows active; the rest preview.
struct ChordProgressionPreview: View {
    let progression: ChordProgression
    var editShape: (() -> Void)?

    var body: some View {
        templatePreviewCard("Chord progression", editShape: editShape) {
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
    var editShape: (() -> Void)?

    var body: some View {
        templatePreviewCard("Strum & chords", editShape: editShape) {
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
/// **Every surface is shown *throughout* the count-in** — it sits static (fully plotted, nothing lit)
/// until the first post-count-in downbeat, then engages. Each surface anchors its own walk/change to
/// the count-in *clearing* rather than to when it appears (`FretboardView`, `StrummingLaneView`,
/// `ChordChangeView`, `StrumChordsView` all do this), so there is no swap mid-count: the surface never
/// disappears during the count and pops back when the music starts. Because nothing swaps, the branch
/// is a plain conditional — no `ZStack`/`.transition` cross-dissolve needed (the previous strum/chord
/// treatment, now retired since they're present from the start like the board).
struct ExerciseTemplateSurface: View {
    let engine: StandaloneMetronomeEngine
    let exercise: Exercise
    var labelMode: FretLabelMode = .none

    @ViewBuilder
    var body: some View {
        if exercise.kind == .fretboard, let drill = exercise.fretboardDrill {
            FretboardView(engine: engine, drill: drill, tint: PocketColor.practice,
                         labelMode: labelMode)
        } else if exercise.kind == .strumming, let pattern = exercise.strumPattern {
            StrummingLaneView(engine: engine, pattern: pattern, tint: PocketColor.practice)
        } else if exercise.kind == .chords, let progression = exercise.chordProgression {
            ChordChangeView(engine: engine, progression: progression, tint: PocketColor.practice)
        } else if exercise.kind == .strumChords, let sheet = exercise.strumChordSheet {
            StrumChordsView(engine: engine, sheet: sheet, tint: PocketColor.practice)
        } else {
            BeatIndicator(engine: engine, tint: PocketColor.practice)
        }
    }
}

/// A titled, rounded card every preview shares. The header carries the title on the left and, when an
/// `editShape` action is supplied (library run screen only, ADR 0077), a compact **Edit shape**
/// affordance on the right — so shape editing sits in the card's own header rather than eating a
/// full-width button below the board.
@MainActor @ViewBuilder
private func templatePreviewCard<Content: View>(_ title: String,
                                                editShape: (() -> Void)? = nil,
                                                @ViewBuilder content: () -> Content) -> some View {
    VStack(spacing: 8) {
        HStack(spacing: 8) {
            Text(title)
                .font(.futura(.caption, weight: .semibold))
                .foregroundStyle(PocketColor.textSecondary)
            Spacer(minLength: 8)
            if let editShape {
                Button {
                    editShape()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "slider.horizontal.3")
                        Text("Edit shape")
                    }
                    .font(.futura(.caption, weight: .semibold))
                    .foregroundStyle(PocketColor.practice)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Edit the shape of this exercise")
            }
        }
        content()
    }
    .padding(14)
    .background(RoundedRectangle(cornerRadius: 14).fill(PocketColor.surfaceSubtle))
}
