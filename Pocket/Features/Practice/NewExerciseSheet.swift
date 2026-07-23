import SwiftUI

/// What a confirmed create produces — passed to `onCreate` so the caller inserts the model through
/// the shared `commandAnchored` factory. Bundles the chosen `template` (immutable after this) and
/// its authored `strum` payload (only for a strumming template) alongside the tempo + meter.
struct NewExercisePlan {
    let name: String
    let command: Int
    let signature: TimeSignature
    let template: ExerciseTemplate
    /// The authored strum pattern for a strumming template; `nil` for every other template.
    let strum: StrumPattern?
    /// The authored fretboard content — a generated run or a custom drill — for a fretboard-family
    /// template; `nil` for every other template.
    let fretboard: FretboardContent?
    /// The authored chord progression for a Chords template; `nil` for every other template.
    let chords: ChordProgression?
    /// The authored strum-chord sheet for a Strum & Chords template; `nil` for every other template.
    let strumChords: StrumChordSheet?
}

/// Create a new exercise from within **Practice** (ADR 0046 / 0068 revised). Two steps: **pick a
/// template** (Strumming, Scales, …) — a first-class choice that fixes the drill's UI, renderer, and
/// library section and can't be changed later — then **configure** the name, command tempo, meter,
/// and (for a strumming template) the arrow pattern itself.
///
/// The automator's "Save as exercise" seam sets `fixedTemplate` to `.basic` to skip the picker and
/// open straight on the configure step — a metronome breakdown is always a plain tempo drill.
struct NewExerciseSheet: View {
    /// Pre-fills the command stepper — the discovered tempo from the automator seam, the engine
    /// default when created fresh in Practice.
    var initialCommand: Int = StandaloneMetronomeEngine.defaultCommandBPM
    /// Pre-fills the meter picker — the metronome's current signature from the automator seam,
    /// 4/4 when created fresh in Practice.
    var initialSignature: TimeSignature = .standard
    /// When set, skips the template picker and opens directly on the configure step for this
    /// template (the automator "Save as exercise" seam, which is always a `.basic` drill).
    var fixedTemplate: ExerciseTemplate?
    /// Called with the assembled plan when the user confirms. The caller inserts the model.
    let onCreate: (NewExercisePlan) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var chosen: ExerciseTemplate?

    var body: some View {
        NavigationStack {
            Group {
                if let fixedTemplate {
                    ConfigureExerciseForm(template: fixedTemplate, initialCommand: initialCommand,
                                          initialSignature: initialSignature, create: create)
                } else {
                    ExerciseTemplatePicker { chosen = $0 }
                }
            }
            .navigationDestination(item: $chosen) { template in
                ConfigureExerciseForm(template: template, initialCommand: initialCommand,
                                      initialSignature: initialSignature, create: create)
            }
            .tint(PocketColor.practice)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func create(_ plan: NewExercisePlan) {
        onCreate(plan)
        dismiss()
    }
}

/// Step two: name the drill, set its command tempo and meter, and — for a template with a bespoke
/// editor (Strumming today) — author its content. A thin form; the strum editor is the same
/// `StrumPatternEditor` the detail sheet uses, seeded from the template's default pattern.
private struct ConfigureExerciseForm: View {
    let template: ExerciseTemplate
    let initialCommand: Int
    let initialSignature: TimeSignature
    let create: (NewExercisePlan) -> Void

    @State private var name = ""
    @State private var command: Int
    @State private var signature: TimeSignature
    /// The authored strum pattern for a strumming template — seeded from the template default and
    /// re-gridded when the meter changes so the lane always matches the bar.
    @State private var strum: StrumPattern
    /// The authored **generated run** for a warm-up-style fretboard template — seeded from the
    /// template default. Not meter-bound: a run defines its own phrase length, so the meter change
    /// doesn't re-grid it.
    @State private var run: FretboardRun
    /// The authored **scale run** for the Scales template — seeded from the template default. Not
    /// meter-bound: a scale run defines its own phrase length.
    @State private var scale: ScaleRun
    /// How a Scales drill authors its content at creation: the generative box picker or the hand-drawn
    /// canvas (ADR 0107) — the same generate-or-draw split the Edit-shape sheet offers.
    @State private var scaleMode: ScaleAuthoringMode = .generate

    /// The two ways a Scales drill's content is authored (mirrors `ExerciseShapeSheet`).
    private enum ScaleAuthoringMode: Hashable { case generate, draw }
    /// The authored **arpeggio run** for the Arpeggios template — seeded from the template default.
    /// Not meter-bound: an arpeggio run defines its own phrase length.
    @State private var arpeggio: ArpeggioRun
    /// The authored **custom drill** for the tap-to-place grid — seeded from the template default and
    /// re-gridded on a meter change so its slots fill the bar.
    @State private var customDrill: FretboardDrill
    /// The authored **chord progression** for the Chords template — seeded from the template default.
    /// Not meter-bound: each change carries its own beat hold.
    @State private var chords: ChordProgression
    /// The authored **strum-chord sheet** for the Strum & Chords template — seeded from the template
    /// default. Its strum pattern is re-gridded on a meter change like `strum` above; its progression
    /// is not meter-bound, same as `chords`.
    @State private var strumChords: StrumChordSheet

    private let range = StandaloneMetronomeEngine.bpmRange

    init(template: ExerciseTemplate, initialCommand: Int, initialSignature: TimeSignature,
         create: @escaping (NewExercisePlan) -> Void) {
        self.template = template
        self.initialCommand = initialCommand
        self.initialSignature = initialSignature
        self.create = create
        _command = State(initialValue: initialCommand)
        _signature = State(initialValue: initialSignature)
        let bars = initialSignature.beats
        let strumSeed = template.defaultStrumPattern ?? .downstrokes(beatsPerBar: bars)
        _strum = State(initialValue: strumSeed.resized(slotsPerBeat: strumSeed.slotsPerBeat,
                                                       beatsPerBar: bars))
        _run = State(initialValue: template.defaultFretboardContent?.runValue ?? .chromaticWarmup)
        _scale = State(initialValue: template.defaultFretboardContent?.scaleValue ?? .aMinorPentatonic)
        _arpeggio = State(initialValue: template.defaultFretboardContent?.arpeggioValue ?? .aMinorSeventh)
        // The custom-grid template starts from the spider-walk canvas; a Scales drill switched to
        // "draw your own" (ADR 0107) starts from an empty neck instead of a pre-filled warm-up.
        let drillSeed = template.defaultFretboardContent?.customValue
            ?? (template.bespokeEditor == .scale ? .emptyBar(beatsPerBar: bars) : .spiderWalk)
        _customDrill = State(initialValue: drillSeed.resized(notesPerBeat: drillSeed.notesPerBeat,
                                                             beatsPerBar: bars))
        _chords = State(initialValue: template.defaultChordProgression ?? .empty)
        let sheetSeed = template.defaultStrumChordSheet ?? .empty
        _strumChords = State(initialValue: StrumChordSheet(
            strumPattern: sheetSeed.strumPattern.resized(
                slotsPerBeat: sheetSeed.strumPattern.slotsPerBeat, beatsPerBar: bars),
            chordProgression: sheetSeed.chordProgression))
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A Chords (or Strum & Chords) drill starts with an empty progression now, so Create also needs at
    /// least one chord placed — an empty progression has nothing to change through.
    private var canCreate: Bool {
        guard !trimmedName.isEmpty else { return false }
        switch template.bespokeEditor {
        case .chords: return !chords.changes.isEmpty
        case .strumChords: return !strumChords.chordProgression.changes.isEmpty
        default: return true
        }
    }

    private func clampCommand(_ value: Int) -> Int {
        min(range.upperBound, max(range.lowerBound, value))
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField(namePlaceholder, text: $name)
            }
            switch template.bespokeEditor {
            case .strumming?: strumSection
            case .run?: runSection
            case .scale?: scaleSection
            case .arpeggio?: arpeggioSection
            case .chords?: chordsSection
            case .strumChords?: strumChordsSection
            case .fretboardGrid?: fretboardSection
            case nil: EmptyView()
            }
            Section {
                EditableTempoRow(label: "Command tempo", caption: "fastest you own · BPM",
                                 value: command, tint: PocketColor.practice,
                                 onStep: { command = clampCommand(command + $0) },
                                 onType: { command = clampCommand($0) })
            } header: {
                FieldInfoLabel(title: "Your command tempo",
                               info: PracticeFieldInfo.exerciseCommandTempo)
            }
            Section {
                Picker("Time signature", selection: $signature) {
                    ForEach(TimeSignature.presets) { preset in
                        Text("\(preset.name) · \(preset.context)").tag(preset)
                    }
                }
            } header: {
                Text("Time signature")
            } footer: {
                Text("Sets the run's accents and count-in length. Defaults to 4/4.")
            }
            templateSection
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("New \(template.displayName.lowercased())")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: signature) { _, meter in
            strum = strum.resized(slotsPerBeat: strum.slotsPerBeat, beatsPerBar: meter.beats)
            customDrill = customDrill.resized(notesPerBeat: customDrill.notesPerBeat,
                                              beatsPerBar: meter.beats)
            strumChords.strumPattern = strumChords.strumPattern.resized(
                slotsPerBeat: strumChords.strumPattern.slotsPerBeat, beatsPerBar: meter.beats)
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") { create(plan) }
                    .disabled(!canCreate)
            }
        }
    }

    /// A compact, read-only reminder of the chosen template — it lives at the **bottom** of the
    /// form (the important inputs are name/pattern/tempo up top) and stays a single row.
    private var templateSection: some View {
        Section {
            HStack {
                Text("Template").foregroundStyle(PocketColor.textPrimary)
                Spacer()
                Image(systemName: template.iconName)
                Text(template.displayName).font(.futura(.subheadline, weight: .semibold))
            }
            .foregroundStyle(PocketColor.practice)
        } footer: {
            Text("Set for this drill and fixed after creation.")
        }
    }

    private var strumSection: some View {
        Section {
            StrumPatternEditor(beatsPerBar: signature.beats, pattern: $strum)
                .listRowBackground(Color.clear)
        } header: {
            Text("Strum pattern")
        } footer: {
            Text("Tap the slots to build the pattern — it plays over the click when you run the "
                 + "drill. You can edit it later too.")
        }
    }

    private var runSection: some View {
        Section {
            FretboardRunEditor(run: $run)
                .listRowBackground(Color.clear)
        } header: {
            Text("Fretboard run")
        } footer: {
            Text("Declare the run's shape — finger pattern, where it sits, how far it travels — and "
                 + "it walks the board over the click. You can edit it later too.")
        }
    }

    private var scaleSection: some View {
        Section {
            Picker("How to author", selection: $scaleMode) {
                Text("Generate").tag(ScaleAuthoringMode.generate)
                Text("Draw your own").tag(ScaleAuthoringMode.draw)
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)

            switch scaleMode {
            case .generate:
                ScaleRunEditor(run: $scale)
                    .listRowBackground(Color.clear)
            case .draw:
                FretboardDrillEditor(beatsPerBar: signature.beats, drill: $customDrill,
                                     referenceEnabled: true)
                    .listRowBackground(Color.clear)
            }
        } header: {
            Text("Scale run")
        } footer: {
            Text(scaleMode == .generate
                 ? "Pick a scale and its root — the box walks the neck over the click. You can change "
                    + "it later too."
                 : "Draw the scale yourself. Turn on a Guide to ghost a scale's notes — including "
                    + "whole-tone and diminished — then tap them up the neck.")
        }
    }

    private var arpeggioSection: some View {
        Section {
            ArpeggioRunEditor(run: $arpeggio)
                .listRowBackground(Color.clear)
        } header: {
            Text("Arpeggio run")
        } footer: {
            Text("Pick a quality and its root — the chord-tone box walks the neck over the click. "
                 + "You can change it later too.")
        }
    }

    private var chordsSection: some View {
        Section {
            ChordProgressionEditor(progression: $chords)
                .listRowBackground(Color.clear)
        } header: {
            Text("Chord progression")
        } footer: {
            Text("Build the progression and how long each chord is held — it changes on the beat "
                 + "over the click. You can edit it later too.")
        }
    }

    private var strumChordsSection: some View {
        Section {
            StrumPatternEditor(beatsPerBar: signature.beats,
                              pattern: $strumChords.strumPattern)
                .listRowBackground(Color.clear)
            // Clear background + zero insets so this reads as a hairline separator, not a phantom
            // inset-grouped row card (device feedback 2026-07-23: without it the bare `Divider` row kept
            // the default rounded row background and looked like a mysterious empty box).
            Divider()
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            ChordProgressionEditor(progression: $strumChords.chordProgression)
                .listRowBackground(Color.clear)
        } header: {
            Text("Strum & chords")
        } footer: {
            Text("The strum lane plays its own repeating groove while the chords change under it — "
                 + "they aren't locked together, so pick a groove length that divides evenly into "
                 + "each chord's hold if you want them to land together. You can edit both later too.")
        }
    }

    private var fretboardSection: some View {
        Section {
            FretboardDrillEditor(beatsPerBar: signature.beats, drill: $customDrill)
                .listRowBackground(Color.clear)
        } header: {
            Text("Fretboard drill")
        } footer: {
            Text("Build the note sequence on the board — it walks the fretboard over the click when "
                 + "you run the drill. You can edit it later too.")
        }
    }

    private var namePlaceholder: String {
        switch template {
        case .strumming: return "e.g. Folk strum"
        case .scales: return "e.g. A minor pentatonic"
        case .arpeggios: return "e.g. A minor 7 arpeggio"
        case .chords: return "e.g. G–C–D changes"
        case .strumChords: return "e.g. Verse groove"
        default: return "e.g. Spider"
        }
    }

    private var plan: NewExercisePlan {
        NewExercisePlan(name: trimmedName, command: command, signature: signature, template: template,
                        strum: template.bespokeEditor == .strumming ? strum : nil,
                        fretboard: fretboardContent,
                        chords: template.bespokeEditor == .chords ? chords : nil,
                        strumChords: template.bespokeEditor == .strumChords ? strumChords : nil)
    }

    /// The fretboard payload the plan carries — a generated run, a custom drill, or `nil` for a
    /// non-fretboard template — matching which editor this template showed.
    private var fretboardContent: FretboardContent? {
        switch template.bespokeEditor {
        case .run: return .run(run)
        // A Scales drill carries its generated box or, in draw mode, the hand-placed custom drill (ADR 0107).
        case .scale: return scaleMode == .draw ? .custom(customDrill) : .scale(scale)
        case .arpeggio: return .arpeggio(arpeggio)
        case .fretboardGrid: return .custom(customDrill)
        case .strumming, .chords, .strumChords, .none: return nil
        }
    }
}

#Preview("New exercise — picker") {
    NewExerciseSheet { _ in }
}

#Preview("New exercise — fixed basic") {
    NewExerciseSheet(fixedTemplate: .basic) { _ in }
}
