import SwiftData
import SwiftUI

/// The **content/shape editor** for one exercise (ADR 0077): where you author *what the drill is* —
/// the finger pattern and reach of a run, the scale/arpeggio and root, the chord progression, the
/// strum lane, or a hand-placed fretboard grid. Relocated off the ⓘ reference sheet onto the library
/// run screen (an "Edit shape" button opens it), so the ⓘ sheet stays purely informational and shape
/// editing lives next to the board it changes. **Library only** — in a routine an exercise is
/// tempo-only (ADR 0077), so this sheet is never presented there.
///
/// The template is **immutable** (ADR 0068): this edits the *content* a template renders, never the
/// template itself. Which editor shows is driven by `exercise.template.bespokeEditor`; each edit is
/// held in local state and committed on Done (a no-op when unchanged, so open-and-close never writes).
struct ExerciseShapeSheet: View {
    let exercise: Exercise

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// The exercise's strumming pattern, held locally and committed on Done (ADR 0065). Seeded from
    /// the stored payload (a strumming exercise always has one), falling back to a bar-matched
    /// downstrokes canvas defensively. Only surfaced/committed for a strumming template.
    @State private var strum: StrumPattern
    /// The exercise's fretboard content, split into the authoring states (ADR 0065 build 2): a
    /// generated `run` (warm-up families), a `scale` run (Scales), an `arpeggio` run (Arpeggios), and
    /// a custom `drill` (grid). Each seeded from the stored payload with defensive fallbacks; only the
    /// one this template uses is surfaced and committed.
    @State private var run: FretboardRun
    @State private var scale: ScaleRun
    @State private var arpeggio: ArpeggioRun
    @State private var customDrill: FretboardDrill
    /// The exercise's chord progression (Chords template), seeded from the stored payload with a
    /// defensive fallback; only surfaced and committed for a chords template.
    @State private var chords: ChordProgression
    /// The exercise's strum-chord sheet (Strum & Chords template), seeded from the stored payload with
    /// a defensive fallback; only surfaced and committed for a strum-chords template.
    @State private var strumChords: StrumChordSheet

    init(exercise: Exercise) {
        self.exercise = exercise
        _strum = State(initialValue: exercise.strumPattern
                       ?? .downstrokes(beatsPerBar: exercise.beatsPerBar))
        let content = exercise.fretboardContent
        _run = State(initialValue: content?.runValue ?? .chromaticWarmup)
        _scale = State(initialValue: content?.scaleValue ?? .aMinorPentatonic)
        _arpeggio = State(initialValue: content?.arpeggioValue ?? .aMinorSeventh)
        _customDrill = State(initialValue: content?.customValue ?? .spiderWalk)
        _chords = State(initialValue: exercise.chordProgression ?? .gMajorPop)
        _strumChords = State(initialValue: exercise.strumChordSheet ?? .popGroove)
    }

    var body: some View {
        NavigationStack {
            Form {
                switch exercise.template.bespokeEditor {
                case .strumming?: strummingSection
                case .run?: runSection
                case .scale?: scaleSection
                case .arpeggio?: arpeggioSection
                case .chords?: chordsSection
                case .strumChords?: strumChordsSection
                case .fretboardGrid?: fretboardSection
                case nil: EmptyView()
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit shape")
            .navigationBarTitleDisplayMode(.inline)
            .tint(PocketColor.practice)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitStrum(); commitFretboard(); commitChords(); commitStrumChords()
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    /// Persist an edited strum pattern on Done, only for a strumming template and only when it
    /// differs from what's stored (ADR 0065). Never touches the template itself (it's immutable).
    private func commitStrum() {
        guard exercise.template.bespokeEditor == .strumming, strum != exercise.strumPattern else {
            return
        }
        exercise.setStrumPattern(strum)
        try? modelContext.save()
    }

    /// Persist edited fretboard content on Done, only for a fretboard-family template and only when
    /// it differs from what's stored (ADR 0065). Assembles the payload from whichever editor this
    /// template shows. Never touches the template itself (it's immutable).
    private func commitFretboard() {
        guard let editor = exercise.template.bespokeEditor else { return }
        let content: FretboardContent
        switch editor {
        case .run: content = .run(run)
        case .scale: content = .scale(scale)
        case .arpeggio: content = .arpeggio(arpeggio)
        case .fretboardGrid: content = .custom(customDrill)
        case .strumming, .chords, .strumChords: return
        }
        guard content != exercise.fretboardContent else { return }
        exercise.setFretboardContent(content)
        try? modelContext.save()
    }

    /// Persist an edited chord progression on Done, only for a chords template and only when it
    /// differs from what's stored (ADR 0065). Never touches the immutable template.
    private func commitChords() {
        guard exercise.template.bespokeEditor == .chords, chords != exercise.chordProgression else {
            return
        }
        exercise.setChordProgression(chords)
        try? modelContext.save()
    }

    /// Persist an edited strum-chord sheet on Done, only for a strum-chords template and only when it
    /// differs from what's stored (ADR 0065). Never touches the immutable template.
    private func commitStrumChords() {
        guard exercise.template.bespokeEditor == .strumChords,
              strumChords != exercise.strumChordSheet else { return }
        exercise.setStrumChordSheet(strumChords)
        try? modelContext.save()
    }
}

// MARK: - How to play (per-template content editor, ADR 0065)

private extension ExerciseShapeSheet {

    /// The strumming template's authoring surface — the tap-to-edit `StrumPatternEditor` over the
    /// exercise's always-present pattern. No "remove" control: the template is immutable, so a
    /// strumming drill stays a strumming drill; you edit the pattern, you don't strip it.
    var strummingSection: some View {
        Section {
            StrumPatternEditor(beatsPerBar: exercise.beatsPerBar, pattern: $strum)
                .listRowBackground(Color.clear)
        } header: {
            Text("How to play — strumming")
        } footer: {
            Text("The arrow lane plays over the click while you run the drill. Slots loop every "
                 + "\(exercise.beatsPerBar) beats.")
        }
    }

    /// The warm-up family's authoring surface — the generative `FretboardRunEditor`. Same
    /// immutability contract: the template stays fretboard; you edit the run's shape.
    var runSection: some View {
        Section {
            FretboardRunEditor(run: $run)
                .listRowBackground(Color.clear)
        } header: {
            Text("How to play — run")
        } footer: {
            Text("Declare the run's shape and it walks the board over the click while you run the "
                 + "drill.")
        }
    }

    /// The Scales template's authoring surface — the `ScaleRunEditor` scale-library picker. Same
    /// immutability contract: the template stays fretboard; you pick the scale and root.
    var scaleSection: some View {
        Section {
            ScaleRunEditor(run: $scale)
                .listRowBackground(Color.clear)
        } header: {
            Text("How to play — scale")
        } footer: {
            Text("Pick a scale and its root; the box walks the neck over the click while you run "
                 + "the drill.")
        }
    }

    /// The Arpeggios template's authoring surface — the `ArpeggioRunEditor` chord-tone picker. Same
    /// immutability contract: the template stays fretboard; you pick the quality and root.
    var arpeggioSection: some View {
        Section {
            ArpeggioRunEditor(run: $arpeggio)
                .listRowBackground(Color.clear)
        } header: {
            Text("How to play — arpeggio")
        } footer: {
            Text("Pick a quality and its root; the chord-tone box walks the neck over the click "
                 + "while you run the drill.")
        }
    }

    /// The Chords template's authoring surface — the `ChordProgressionEditor`. Same immutability
    /// contract: the template stays chords; you edit the progression, not the type.
    var chordsSection: some View {
        Section {
            ChordProgressionEditor(progression: $chords)
                .listRowBackground(Color.clear)
        } header: {
            Text("How to play — chords")
        } footer: {
            Text("The chords change on the beat over the click while you run the drill. The "
                 + "progression loops.")
        }
    }

    /// The Strum & Chords template's authoring surface — the `StrumPatternEditor` and
    /// `ChordProgressionEditor` stacked, editing the two halves of the exercise's `StrumChordSheet`.
    /// Same immutability contract: the template stays strum-chords.
    var strumChordsSection: some View {
        Section {
            StrumPatternEditor(beatsPerBar: exercise.beatsPerBar,
                              pattern: $strumChords.strumPattern)
                .listRowBackground(Color.clear)
            Divider()
            ChordProgressionEditor(progression: $strumChords.chordProgression)
                .listRowBackground(Color.clear)
        } header: {
            Text("How to play — strum & chords")
        } footer: {
            Text("The strum lane loops on its own while the chords change over the click — the two "
                 + "aren't locked together.")
        }
    }

    /// The custom-drill authoring surface — the tap-to-place `FretboardDrillEditor`. Same
    /// immutability contract: the template stays fretboard.
    var fretboardSection: some View {
        Section {
            FretboardDrillEditor(beatsPerBar: exercise.beatsPerBar, drill: $customDrill)
                .listRowBackground(Color.clear)
        } header: {
            Text("How to play — fretboard")
        } footer: {
            Text("The notes walk the board over the click while you run the drill. Slots loop every "
                 + "\(exercise.beatsPerBar) beats.")
        }
    }
}

#Preview("Exercise shape — strumming") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Exercise.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    let exercise = Exercise(name: "Folk strum", currentTempo: 70, commandTempo: 96,
                            template: .strumming, tags: ["rhythm", "strumming"])
    exercise.setStrumPattern(.folk)
    container.mainContext.insert(exercise)
    return ExerciseShapeSheet(exercise: exercise)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
