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
    /// How a **Scales** drill authors its content: the generative box picker or the hand-drawn canvas
    /// (the custom-scale surface). Seeded from the stored content — a Scales exercise already holding a
    /// `.custom` drill opens in draw mode. Only meaningful for the scales template.
    @State private var scaleMode: AuthoringMode
    /// How a **run-family** drill (warm-up/picking/legato/fingerstyle) authors its content: the
    /// generative `FretboardRunEditor` or the same hand-drawn canvas. Seeded from the stored content —
    /// a run exercise already holding a `.custom` drill opens in draw mode. Only meaningful for `.run`.
    @State private var runMode: AuthoringMode
    /// How an **Arpeggios** drill authors its content: the generative `ArpeggioRunEditor` chord-tone box
    /// picker or the same hand-drawn canvas (ADR 0107). Seeded from the stored content — an arpeggio
    /// exercise already holding a `.custom` drill opens in draw mode. Only meaningful for `.arpeggio`.
    @State private var arpeggioMode: AuthoringMode

    /// The two ways a fretboard drill's content is authored (the generate-or-draw split).
    private enum AuthoringMode: Hashable { case generate, draw }

    init(exercise: Exercise) {
        self.exercise = exercise
        _strum = State(initialValue: exercise.strumPattern
                       ?? .downstrokes(beatsPerBar: exercise.beatsPerBar))
        let content = exercise.fretboardContent
        _run = State(initialValue: content?.runValue ?? .chromaticWarmup)
        _scale = State(initialValue: content?.scaleValue ?? .aMinorPentatonic)
        _arpeggio = State(initialValue: content?.arpeggioValue ?? .aMinorSeventh)
        // A Scales, run-family, *or* Arpeggios drill drawn by hand opens the empty canvas; the
        // custom-grid template keeps the spider-walk starter. A stored custom drill (any drawable
        // template) seeds itself and opens in draw mode.
        let editor = exercise.template.bespokeEditor
        let drawnCustom = content?.customValue != nil
        let drawableEditor = editor == .scale || editor == .run || editor == .arpeggio
        let customDefault: FretboardDrill = drawableEditor
            ? .emptyBar(beatsPerBar: exercise.beatsPerBar) : .spiderWalk
        _customDrill = State(initialValue: content?.customValue ?? customDefault)
        _scaleMode = State(initialValue: editor == .scale && drawnCustom ? .draw : .generate)
        _runMode = State(initialValue: editor == .run && drawnCustom ? .draw : .generate)
        _arpeggioMode = State(initialValue: editor == .arpeggio && drawnCustom ? .draw : .generate)
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
        // A run-family drill writes its generated run or, in draw mode, the hand-placed custom drill.
        case .run: content = runMode == .draw ? .custom(customDrill) : .run(run)
        // A Scales drill writes its generated box or, in draw mode, the hand-placed custom drill.
        case .scale: content = scaleMode == .draw ? .custom(customDrill) : .scale(scale)
        // An Arpeggios drill writes its generated chord-tone box or, in draw mode, the custom drill.
        case .arpeggio: content = arpeggioMode == .draw ? .custom(customDrill) : .arpeggio(arpeggio)
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

    /// The warm-up family's authoring surface — a **generate-or-draw** split (ADR 0107): the generative
    /// `FretboardRunEditor` (generate), or the tap-to-place `FretboardDrillEditor` with its scale guide
    /// (draw your own), the escape hatch for any hand-shaped run the generator can't declare. Same
    /// immutability contract: the template stays a fretboard run; you edit its shape.
    var runSection: some View {
        Section {
            Picker("How to author", selection: $runMode) {
                Text("Generate").tag(AuthoringMode.generate)
                Text("Draw your own").tag(AuthoringMode.draw)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            switch runMode {
            case .generate:
                FretboardRunEditor(run: $run, instrument: exercise.instrument)
                    .listRowBackground(Color.clear)
            case .draw:
                FretboardDrillEditor(beatsPerBar: exercise.beatsPerBar, drill: $customDrill,
                                     referenceEnabled: true)
                    .listRowBackground(Color.clear)
            }
        } header: {
            Text("How to play — run")
        } footer: {
            Text(runMode == .generate
                 ? "Declare the run's shape and it walks the board over the click while you run the "
                    + "drill."
                 : "Draw the run yourself — tap the notes onto the board. Turn on a Guide to ghost a "
                    + "scale's notes to trace.")
        }
    }

    /// The Scales template's authoring surface — a **generate-or-draw** split: the `ScaleRunEditor`
    /// box picker (generate), or the tap-to-place `FretboardDrillEditor` with its scale guide (draw your
    /// own), the escape hatch for scales the box generator can't place (whole-tone, diminished) and any
    /// hand-shaped run. Same immutability contract: the template stays a fretboard scales drill.
    var scaleSection: some View {
        Section {
            Picker("How to author", selection: $scaleMode) {
                Text("Generate").tag(AuthoringMode.generate)
                Text("Draw your own").tag(AuthoringMode.draw)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            switch scaleMode {
            case .generate:
                ScaleRunEditor(run: $scale, instrument: exercise.instrument)
                    .listRowBackground(Color.clear)
            case .draw:
                FretboardDrillEditor(beatsPerBar: exercise.beatsPerBar, drill: $customDrill,
                                     referenceEnabled: true)
                    .listRowBackground(Color.clear)
            }
        } header: {
            Text("How to play — scale")
        } footer: {
            Text(scaleMode == .generate
                 ? "Pick a scale and its root; the box walks the neck over the click while you run "
                    + "the drill."
                 : "Draw the scale yourself. Turn on a Guide to ghost a scale's notes on the board — "
                    + "including whole-tone and diminished — then tap them up the neck.")
        }
    }

    /// The Arpeggios template's authoring surface — a **generate-or-draw** split (ADR 0107): the
    /// `ArpeggioRunEditor` chord-tone box picker (generate), or the tap-to-place `FretboardDrillEditor`
    /// with its scale guide (draw your own), the escape hatch for any hand-shaped arpeggio the box
    /// generator can't declare. Same immutability contract: the template stays fretboard.
    var arpeggioSection: some View {
        Section {
            Picker("How to author", selection: $arpeggioMode) {
                Text("Generate").tag(AuthoringMode.generate)
                Text("Draw your own").tag(AuthoringMode.draw)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            switch arpeggioMode {
            case .generate:
                ArpeggioRunEditor(run: $arpeggio, instrument: exercise.instrument)
                    .listRowBackground(Color.clear)
            case .draw:
                FretboardDrillEditor(beatsPerBar: exercise.beatsPerBar, drill: $customDrill,
                                     referenceEnabled: true, guideCatalog: ScaleReference.arpeggios)
                    .listRowBackground(Color.clear)
            }
        } header: {
            Text("How to play — arpeggio")
        } footer: {
            Text(arpeggioMode == .generate
                 ? "Pick a quality and its root; the chord-tone box walks the neck over the click "
                    + "while you run the drill."
                 : "Draw the arpeggio yourself — tap the chord tones onto the board. Turn on a Guide "
                    + "to ghost an arpeggio's chord tones to trace.")
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
            // One row with an in-VStack hairline — a standalone `Divider` row rendered as a phantom
            // empty box between the Form's row separators (device feedback 2026-07-23).
            VStack(spacing: 14) {
                StrumPatternEditor(beatsPerBar: exercise.beatsPerBar,
                                   pattern: $strumChords.strumPattern)
                Divider()
                ChordProgressionEditor(progression: $strumChords.chordProgression)
            }
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
