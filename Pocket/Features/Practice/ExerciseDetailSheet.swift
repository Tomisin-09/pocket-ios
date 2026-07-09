import SwiftData
import SwiftUI

/// A reference sheet for one exercise (V1 feedback #2): the place to read — and lightly annotate —
/// what an exercise *is*, kept separate from the run-setup tuning. It surfaces the exercise's
/// **template** (read-only — set at creation, immutable, ADR 0068), an editable **description** (the
/// model's `notes`), the tempo anchors (working / command / reach), the meter + subdivision, a
/// read-only preview of the training routine staircase, and — for a **strumming** template — the
/// tap-to-edit arrow-pattern editor. Reached from the exercise run screen's nav bar (ⓘ).
///
/// The description and (for strumming) the pattern are the only editable fields; they're committed
/// to the model on Done / dismiss (a no-op when unchanged) so a quick open-and-close never writes.
/// Everything else is read-only — the tempos and routine are tuned on the run screen, not here.
struct ExerciseDetailSheet: View {
    let exercise: Exercise

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var notes: String
    /// The exercise's self-rated mastery (0–5, `nil` = unrated), held locally and committed on
    /// Done — the planner's dueScore *need* signal (V2 planner Slice 1, ADR 0070: self-set, never
    /// measured). Mirrors the loop editor's mastery dots.
    @State private var mastery: Int?
    /// The exercise's strumming pattern, held locally and committed on Done (ADR 0065). Seeded from
    /// the stored payload (a strumming exercise always has one), falling back to a bar-matched
    /// downstrokes canvas defensively. Only surfaced/committed for a strumming template.
    @State private var strum: StrumPattern
    /// The exercise's fretboard content, split into the authoring states (ADR 0065 build 2): a
    /// generated `run` (warm-up families), a `scale` run (Scales), and a custom `drill` (grid). Each
    /// seeded from the stored payload with defensive fallbacks; only the one this template uses is
    /// surfaced and committed.
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
    /// The edited **command** tempo (ADR 0071 R4) — nudged in `ExerciseTempoSection` and committed on
    /// Done via the canonical `promoteCommand` setter (the same mutation the run screen uses, so no
    /// second write path diverges, ADR 0057). Only editable for a measured command.
    @State private var command: Int

    init(exercise: Exercise) {
        self.exercise = exercise
        _notes = State(initialValue: exercise.notes)
        _mastery = State(initialValue: exercise.mastery)
        _command = State(initialValue: exercise.command)
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
                templateSection
                descriptionSection
                ExerciseProgressSection(mastery: $mastery, lastPracticed: exercise.lastPracticed)
                ExerciseTempoSection(exercise: exercise, command: $command)
                feelSection
                routineSection
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
            .navigationTitle(exercise.name.isEmpty ? "Exercise" : exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .tint(PocketColor.practice)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitNotes(); commitMastery(); commitCommand(); commitStrum()
                        commitFretboard(); commitChords(); commitStrumChords(); dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Template (read-only, ADR 0068)

    /// The exercise's template — set at creation and **immutable** (ADR 0068). Shown so the drill's
    /// type reads at a glance; not editable, because changing it would mean a different renderer and
    /// a different authoring surface (delete + recreate to change type).
    private var templateSection: some View {
        Section {
            LabeledContent("Template") {
                Label(exercise.template.displayName, systemImage: exercise.template.iconName)
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(PocketColor.practice)
            }
        } footer: {
            Text("The kind of drill, set when it was created. It groups the exercise in your "
                 + "library and can't be changed.")
        }
    }

    // MARK: - Description (editable) + tags

    private var descriptionSection: some View {
        Section {
            TextField("Technique cues, target feel, where it's from…", text: $notes, axis: .vertical)
                .lineLimit(3...8)
            if !exercise.tags.isEmpty {
                FlowLayout(spacing: 6) {
                    ForEach(exercise.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.futura(.caption, weight: .semibold))
                            .foregroundStyle(PocketColor.practice)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(PocketColor.practice.opacity(0.16)))
                    }
                }
                .padding(.vertical, 2)
            }
        } header: {
            Text("Description")
        } footer: {
            Text("A note to yourself about the drill — saved with the exercise.")
        }
    }

    // MARK: - Meter & subdivision (read-only)

    private var feelSection: some View {
        Section("Feel") {
            LabeledContent("Time signature") {
                Text(exercise.timeSignatureLabel).font(.pocketMono(.body))
            }
            LabeledContent("Subdivision") { Text(exercise.subdivision.label) }
        }
    }

    // MARK: - Routine preview (read-only)

    private var routineSection: some View {
        Section {
            RoutineStairs(plateaus: exercise.ramp.plateaus, tint: PocketColor.practice)
                .frame(height: 120)
                .listRowBackground(Color.clear)
        } header: {
            Text("Training routine")
        } footer: {
            Text("Warm up from working to command, hold there, summit briefly at the reach, then back "
                 + "off — the shape a run climbs. Adjust the steps on the run screen.")
        }
    }

    // MARK: - Helpers

    /// Persist an edited description, trimmed. A no-op when unchanged, so opening and closing the
    /// sheet without touching the field never writes to the store.
    private func commitNotes() {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != exercise.notes else { return }
        exercise.notes = trimmed
        try? modelContext.save()
    }

    /// Persist an edited command tempo on Done via the canonical `promoteCommand` setter — the *same*
    /// mutation the run screen uses (so the two surfaces never diverge, ADR 0057), which also
    /// recomputes the reach. Only for a measured command and only when it actually changed.
    private func commitCommand() {
        guard exercise.hasMeasuredCommand, command != exercise.command else { return }
        exercise.promoteCommand(to: command)
        try? modelContext.save()
    }

    /// Persist an edited mastery rating on Done, only when it differs from what's stored — a
    /// deliberate self-assessment (ADR 0070), never computed from playing.
    private func commitMastery() {
        guard mastery != exercise.mastery else { return }
        exercise.mastery = mastery
        try? modelContext.save()
    }

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

private extension ExerciseDetailSheet {

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

#Preview("Exercise detail — strumming") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Exercise.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    let exercise = Exercise(name: "Folk strum", currentTempo: 70, commandTempo: 96,
                            template: .strumming, tags: ["rhythm", "strumming"],
                            notes: "Keep the hand swinging in steady eighths.")
    exercise.setStrumPattern(.folk)
    container.mainContext.insert(exercise)
    return ExerciseDetailSheet(exercise: exercise)
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
