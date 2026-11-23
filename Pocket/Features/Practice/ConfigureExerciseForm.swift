import SwiftData
import SwiftUI

/// Step two of `NewExerciseSheet`: name the drill, set its command tempo and meter, link the songs
/// it's *for*, and — for a template with a bespoke editor — author its content. A thin form; each
/// editor is the same one the library's Edit-shape sheet uses, seeded from the template's default
/// payload.
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
    /// Songs the link picker (ADR 0111) starts with already ticked. Empty for both original hosts —
    /// a drill authored in Practice or saved out of the automator knows of no song. The song
    /// player's tempo-carry gateway (ADR 0170) passes the song the tempo was read off, because that
    /// is the one fact that route knows and the form cannot infer.
    let initialSongs: [Song]
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
    /// Which shape an Arpeggios drill generates (ADR 0313 D2): the box it opens on, or triads.
    @State var arpeggioShape: ArpeggioShape = .box
    /// The Triads run, opening on the run D10 describes.
    @State var triads: TriadRun = .starter
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
    /// The player's own written instructions — the whole content of a **freeform** block (ADR 0136
    /// F2). Starts empty; there is nothing to seed it with, and the field's own prompt says more than
    /// a specimen drill would.
    @State var instructions = ""
    /// The player's declaration that this block needs no instrument (ADR 0139 O6). Off by default —
    /// most practice wants the guitar, and a box that starts ticked is a guess, which is the one
    /// thing this must never be.
    @State var awayFromInstrument = false

    /// Every song in the library, offered as link candidates (ADR 0111) — sorted by title to match
    /// the Library and `ExerciseDetailSheet`'s picker.
    @Query(sort: \Song.title) var allSongs: [Song]
    /// The songs picked *so far* on this step. Held locally and carried onto the plan rather than
    /// written through: nothing exists to link to until Create, and abandoning the sheet must leave
    /// the library untouched. (Contrast `ExerciseDetailSheet`, where the drill already exists and each
    /// toggle persists immediately.)
    @State var pickedSongs: [Song]
    @State var showingSongPicker = false

    /// The instrument this drill draws and generates for — fixed at the create sheet (S6), so it's just
    /// the seed value the editors and the plan read. Not `@State`: nothing on this step changes it.
    var instrument: Instrument { initialInstrument }

    /// Whether switching to Triads carries the box's key (ADR 0313 D2): only once the player has changed
    /// the box. A new drill's box is the template's seed, so untouched, Triads opens on D10's run.
    var carriesBoxKey: Bool { arpeggio != Self.seededArpeggio(template: template, instrument: instrument) }

    private let range = StandaloneMetronomeEngine.bpmRange

    /// What the drill works on (ADR 0216 D1), held locally and carried on the plan like the songs. It starts
    /// with a goal skill's fix's skill (D4), and on Basic and Your own practice **Works on** sets it (ADR 0309
    /// D4); elsewhere the drill follows its type.
    @State var pickedSkillIDs: [String]
    @State var showingSkillPicker = false
    /// The picker's working copies, bound to `SkillPickerSheet` and read back when it closes.
    @State var skillOffered: [String] = []
    @State var skillKept: Set<String> = []
    /// The player's own skills, so a custom id reads as its name.
    @Query var customSkills: [CustomSkill]
    /// Both goal tiers, for the line naming the goals the skills serve.
    @Query var longTermGoals: [LongTermGoal]
    @Query var plannerGoals: [Goal]

    /// `initialName` and `initialTriads` come from a door that knows the exercise (`NewExerciseSeed`,
    /// ADR 0313 D9): the form opens named, and an Arpeggios form on Triads with that run.
    init(template: ExerciseTemplate, initialCommand: Int, initialSignature: TimeSignature,
         initialInstrument: Instrument = .guitar, initialSongs: [Song] = [],
         initialSkillIDs: [String] = [], initialName: String = "", initialTriads: TriadRun? = nil,
         create: @escaping (NewExercisePlan) -> Void) {
        self.template = template
        _name = State(initialValue: initialName)
        if let initialTriads {
            _triads = State(initialValue: initialTriads)
            _arpeggioShape = State(initialValue: .triads)
        }
        self.initialCommand = initialCommand
        self.initialSignature = initialSignature
        self.initialInstrument = initialInstrument
        self.initialSongs = initialSongs
        self.create = create
        _pickedSongs = State(initialValue: initialSongs)
        _pickedSkillIDs = State(initialValue: initialSkillIDs)
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
            case .freeform?: instructionsSection
            case nil: EmptyView()
            }
            // A freeform block has no tempo and no meter (ADR 0136 F3): most of what belongs in one —
            // sight-reading, transcribing, a teacher's assignment — has no BPM at all, and a stepper
            // whose value the run screen never reads is a question with no honest answer.
            if template != .freeform { tempoAndMeterSections }
            songsSection
            worksOnSection
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
        .sheet(isPresented: $showingSongPicker) {
            LinkPickerSheet(
                title: "Link songs",
                prompt: "Search songs",
                emptyCatalog: "No songs in your library yet.",
                candidates: allSongs,
                label: { $0.title.isEmpty ? "Untitled song" : $0.title },
                subtitle: { $0.artist.isEmpty ? nil : $0.artist },
                isLinked: { isPicked($0) },
                toggle: { togglePick($0) },
                accent: PocketColor.practice)
        }
        // At the form, never on the section's row: a sheet raised from a row loses its write on iOS 18.
        .sheet(isPresented: $showingSkillPicker, onDismiss: commitPickedSkills) {
            SkillPickerSheet(offeredSkillIDs: $skillOffered, keptSkillIDs: $skillKept, title: "Works on")
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") { create(plan) }
                    .disabled(!canCreate)
            }
        }
    }
}

// MARK: - Sections

private extension ConfigureExerciseForm {
    /// The command tempo and meter — every template's settings except a freeform block's, which has
    /// neither (ADR 0136 F3). Lifted out of `body` so the one `if` reads as the exception it is.
    @ViewBuilder var tempoAndMeterSections: some View {
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
    }

    /// A freeform block's one authoring surface (ADR 0136 F2a): the player's own words, which *are*
    /// the exercise. The footer says what the app will and won't do with them — F8's "Pocket holds the
    /// block; the player fills it", in the one place a player might expect otherwise.
    var instructionsSection: some View {
        Section {
            TextField("What are you practising?", text: $instructions, axis: .vertical)
                .lineLimit(4...12)
            Toggle("I can do this without my instrument", isOn: $awayFromInstrument)
        } header: {
            Text("Instructions")
        } footer: {
            Text("Sight-reading, transcribing, a piece you're working by hand, dialling in your pedals, "
                 + "building loops on a looper, something your teacher set — whatever Red Moon doesn't "
                 + "cover. You'll see this while you practise. Nothing reads it but you.\n\nTick the box and "
                 + "this can turn up in an \u{201C}Away from your instrument\u{201D} session — a commute, a "
                 + "quiet room. "
                 + "We can't tell from what you wrote, so it's your call.")
        }
    }
}

// MARK: - Derived state

private extension ConfigureExerciseForm {
    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedInstructions: String {
        instructions.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A Chords (or Strum & Chords) drill starts with an empty progression now, so Create also needs at
    /// least one chord placed — an empty progression has nothing to change through. A **freeform**
    /// block is gated the same way and for the same reason: its instructions *are* its content
    /// (ADR 0136 F2), so one with none is the empty block F9 refuses to ship.
    ///
    /// A **generated run** joins them: its finger pattern is now clearable to empty, so that the first
    /// finger can be something other than 1, and an empty pattern expands to a drill with no notes.
    /// Draw mode is untouched — there the run isn't the payload.
    var canCreate: Bool {
        guard !trimmedName.isEmpty else { return false }
        switch template.bespokeEditor {
        case .chords: return !chords.changes.isEmpty
        case .strumChords: return !strumChords.chordProgression.changes.isEmpty
        case .freeform: return !trimmedInstructions.isEmpty
        case .run: return runMode == .draw || !run.fingers.isEmpty
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
                        strumChords: template.bespokeEditor == .strumChords ? strumChords : nil,
                        notes: template == .freeform ? trimmedInstructions : "",
                        awayFromInstrument: template == .freeform && awayFromInstrument,
                        songs: pickedSongs,
                        skillIDs: pickedSkillIDs)
    }

    /// The generated seed for a fresh run/scale/arpeggio at a given instrument — the template's guitar
    /// default, or the bass flagship (ADR 0116).
    static func seededRun(template: ExerciseTemplate, instrument: Instrument) -> FretboardRun {
        let guitar = template.starterRun
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
        // An Arpeggios drill carries its generated box or triads (ADR 0313, guitar only) or, in draw
        // mode, the custom drill.
        case .arpeggio:
            if arpeggioMode == .draw { return .custom(customDrill) }
            return arpeggioShape == .triads && instrument == .guitar ? .triads(triads) : .arpeggio(arpeggio)
        case .fretboardGrid: return .custom(customDrill)
        case .strumming, .chords, .strumChords, .freeform, .none: return nil
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
    // A container is required now that the form queries songs for the link picker; seeding one song
    // is also what makes the Songs section appear (it hides itself on an empty library).
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Song.self, Exercise.self, Loop.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    container.mainContext.insert(Song.sample())
    return NavigationStack {
        ConfigureExerciseForm(template: .warmup,
                              initialCommand: StandaloneMetronomeEngine.defaultCommandBPM,
                              initialSignature: .standard) { _ in }
    }
    .tint(PocketColor.practice)
    .modelContainer(container)
}
