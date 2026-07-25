import SwiftUI

/// Step two of `NewExerciseSheet`: name the drill, set its command tempo and meter, and — for a
/// template with a bespoke editor — author its content. A thin form; each editor is the same one the
/// library's Edit-shape sheet uses, seeded from the template's default payload.
///
/// Fretboard-family templates that can be either **generated or hand-drawn** (Scales and the run
/// families — warm-up/picking/legato/fingerstyle) carry a generate-or-draw toggle (ADR 0107); draw
/// mode emits a `.custom` drill, generate mode the family's declared run.
struct ConfigureExerciseForm: View {
    let template: ExerciseTemplate
    let initialCommand: Int
    let initialSignature: TimeSignature
    /// The instrument this drill is fixed to (ADR 0116) — chosen on the create sheet's Guitar/Bass
    /// control *before* this form (S6), so it's set once here and rides onto the plan. The form seeds its
    /// generated content and draw canvas for it in `init`; it isn't editable on this step.
    let initialInstrument: Instrument
    let create: (NewExercisePlan) -> Void

    @State var name = ""
    @State var command: Int
    @State var signature: TimeSignature
    /// The authored strum pattern for a strumming template — seeded from the template default and
    /// re-gridded when the meter changes so the lane always matches the bar.
    @State var strum: StrumPattern
    /// The authored **generated run** for a warm-up-style fretboard template — seeded from the
    /// template default. Not meter-bound: a run defines its own phrase length, so the meter change
    /// doesn't re-grid it.
    @State var run: FretboardRun
    /// The authored **scale run** for the Scales template — seeded from the template default. Not
    /// meter-bound: a scale run defines its own phrase length.
    @State var scale: ScaleRun
    /// How a Scales drill authors its content at creation: the generative box picker or the hand-drawn
    /// canvas (ADR 0107) — the same generate-or-draw split the Edit-shape sheet offers.
    @State var scaleMode: AuthoringMode = .generate
    /// How a run-family drill (warm-up/picking/legato/fingerstyle) authors its content: the generative
    /// `FretboardRunEditor` or the same hand-drawn canvas the Scales drill offers.
    @State var runMode: AuthoringMode = .generate

    /// The two ways a fretboard drill's content is authored (mirrors `ExerciseShapeSheet`).
    enum AuthoringMode: Hashable { case generate, draw }
    /// The authored **arpeggio run** for the Arpeggios template — seeded from the template default.
    /// Not meter-bound: an arpeggio run defines its own phrase length.
    @State var arpeggio: ArpeggioRun
    /// How an Arpeggios drill authors its content at creation: the generative chord-tone box picker or
    /// the hand-drawn canvas (ADR 0107) — the same generate-or-draw split the Scales drill offers.
    @State var arpeggioMode: AuthoringMode = .generate
    /// The authored **custom drill** for the tap-to-place grid — seeded from the template default and
    /// re-gridded on a meter change so its slots fill the bar.
    @State var customDrill: FretboardDrill
    /// The authored **chord progression** for the Chords template — seeded from the template default.
    /// Not meter-bound: each change carries its own beat hold.
    @State var chords: ChordProgression
    /// The authored **strum-chord sheet** for the Strum & Chords template — seeded from the template
    /// default. Its strum pattern is re-gridded on a meter change like `strum` above; its progression
    /// is not meter-bound, same as `chords`.
    @State var strumChords: StrumChordSheet

    /// The instrument this drill draws and generates for — fixed at the create sheet (S6), so it's just
    /// the seed value the editors and the plan read. Not `@State`: nothing on this step changes it.
    var instrument: Instrument { initialInstrument }

    private let range = StandaloneMetronomeEngine.bpmRange

    init(template: ExerciseTemplate, initialCommand: Int, initialSignature: TimeSignature,
         initialInstrument: Instrument = .guitar,
         create: @escaping (NewExercisePlan) -> Void) {
        self.template = template
        self.initialCommand = initialCommand
        self.initialSignature = initialSignature
        self.initialInstrument = initialInstrument
        self.create = create
        _command = State(initialValue: initialCommand)
        _signature = State(initialValue: initialSignature)
        let bars = initialSignature.beats
        let strumSeed = template.defaultStrumPattern ?? .downstrokes(beatsPerBar: bars)
        _strum = State(initialValue: strumSeed.resized(slotsPerBeat: strumSeed.slotsPerBeat,
                                                       beatsPerBar: bars))
        _run = State(initialValue: Self.seededRun(template: template, instrument: initialInstrument))
        _scale = State(initialValue: Self.seededScale(template: template, instrument: initialInstrument))
        _arpeggio = State(initialValue: Self.seededArpeggio(template: template,
                                                            instrument: initialInstrument))
        // The custom-grid template starts from the spider-walk canvas; a Scales, run-family, *or*
        // Arpeggios drill switched to "draw your own" (ADR 0107) starts from an empty neck instead of a
        // pre-filled warm-up. Bass draws its own string count (ADR 0116).
        let drawStartsEmpty = template.bespokeEditor == .scale || template.bespokeEditor == .run
            || template.bespokeEditor == .arpeggio
        let drillSeed: FretboardDrill
        if initialInstrument != .guitar {
            // Every guitar seed (the custom-value default, the spider-walk) is six-string, so a bass drill
            // starts from an empty four-string bar instead, tuned to bass so its labels/guide read in bass
            // tuning (ADR 0116 S5).
            drillSeed = .emptyBar(beatsPerBar: bars, stringCount: initialInstrument.stringCount,
                                  openMidi: initialInstrument.engineOpenMidi)
        } else {
            drillSeed = template.defaultFretboardContent?.customValue
                ?? (drawStartsEmpty ? .emptyBar(beatsPerBar: bars) : .spiderWalk)
        }
        _customDrill = State(initialValue: drillSeed.resized(notesPerBeat: drillSeed.notesPerBeat,
                                                             beatsPerBar: bars))
        _chords = State(initialValue: template.defaultChordProgression ?? .empty)
        let sheetSeed = template.defaultStrumChordSheet ?? .empty
        _strumChords = State(initialValue: StrumChordSheet(
            strumPattern: sheetSeed.strumPattern.resized(
                slotsPerBeat: sheetSeed.strumPattern.slotsPerBeat, beatsPerBar: bars),
            chordProgression: sheetSeed.chordProgression))
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
}

// MARK: - Derived state

private extension ConfigureExerciseForm {
    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A Chords (or Strum & Chords) drill starts with an empty progression now, so Create also needs at
    /// least one chord placed — an empty progression has nothing to change through.
    var canCreate: Bool {
        guard !trimmedName.isEmpty else { return false }
        switch template.bespokeEditor {
        case .chords: return !chords.changes.isEmpty
        case .strumChords: return !strumChords.chordProgression.changes.isEmpty
        default: return true
        }
    }

    func clampCommand(_ value: Int) -> Int {
        min(range.upperBound, max(range.lowerBound, value))
    }

    var plan: NewExercisePlan {
        NewExercisePlan(name: trimmedName, command: command, signature: signature, template: template,
                        instrument: instrument,
                        strum: template.bespokeEditor == .strumming ? strum : nil,
                        fretboard: fretboardContent,
                        chords: template.bespokeEditor == .chords ? chords : nil,
                        strumChords: template.bespokeEditor == .strumChords ? strumChords : nil)
    }

    /// The generated seed for a fresh run/scale/arpeggio at a given instrument — the template's guitar
    /// default, or the bass flagship (ADR 0116).
    static func seededRun(template: ExerciseTemplate, instrument: Instrument) -> FretboardRun {
        let guitar = template.defaultFretboardContent?.runValue ?? .chromaticWarmup
        return instrument == .guitar ? guitar : guitar.stringClamped(to: instrument.stringCount)
    }

    static func seededScale(template: ExerciseTemplate, instrument: Instrument) -> ScaleRun {
        instrument == .bass ? .eMinorPentatonicBass
            : (template.defaultFretboardContent?.scaleValue ?? .aMinorPentatonic)
    }

    static func seededArpeggio(template: ExerciseTemplate, instrument: Instrument) -> ArpeggioRun {
        instrument == .bass ? .eMinorSeventhBass
            : (template.defaultFretboardContent?.arpeggioValue ?? .aMinorSeventh)
    }

    /// The fretboard payload the plan carries — a generated run, a custom drill, or `nil` for a
    /// non-fretboard template — matching which editor this template showed.
    var fretboardContent: FretboardContent? {
        switch template.bespokeEditor {
        // A run-family drill carries its generated run or, in draw mode, the hand-placed custom drill (ADR 0107).
        case .run: return runMode == .draw ? .custom(customDrill) : .run(run)
        // A Scales drill carries its generated box or, in draw mode, the hand-placed custom drill (ADR 0107).
        case .scale: return scaleMode == .draw ? .custom(customDrill) : .scale(scale)
        // An Arpeggios drill carries its generated chord-tone box or, in draw mode, the custom drill.
        case .arpeggio: return arpeggioMode == .draw ? .custom(customDrill) : .arpeggio(arpeggio)
        case .fretboardGrid: return .custom(customDrill)
        case .strumming, .chords, .strumChords, .none: return nil
        }
    }

    var namePlaceholder: String {
        switch template {
        case .strumming: return "e.g. Folk strum"
        case .scales: return "e.g. A minor pentatonic"
        case .arpeggios: return "e.g. A minor 7 arpeggio"
        case .chords: return "e.g. G–C–D changes"
        case .strumChords: return "e.g. Verse groove"
        default: return "e.g. Spider"
        }
    }
}

#Preview("Configure — warm-up (draw toggle)") {
    NavigationStack {
        ConfigureExerciseForm(template: .warmup,
                              initialCommand: StandaloneMetronomeEngine.defaultCommandBPM,
                              initialSignature: .standard) { _ in }
    }
    .tint(PocketColor.practice)
}
