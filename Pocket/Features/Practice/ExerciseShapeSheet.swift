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
    @State var strum: StrumPattern
    /// The exercise's fretboard content, split into the authoring states (ADR 0065 build 2): a
    /// generated `run` (warm-up families), a `scale` run (Scales), an `arpeggio` run (Arpeggios), and
    /// a custom `drill` (grid). Each seeded from the stored payload with defensive fallbacks; only the
    /// one this template uses is surfaced and committed.
    @State var run: FretboardRun
    @State var scale: ScaleRun
    @State var arpeggio: ArpeggioRun
    @State var customDrill: FretboardDrill
    /// The exercise's chord progression (Chords template), seeded from the stored payload with a
    /// defensive fallback; only surfaced and committed for a chords template.
    @State var chords: ChordProgression
    /// The exercise's strum-chord sheet (Strum & Chords template), seeded from the stored payload with
    /// a defensive fallback; only surfaced and committed for a strum-chords template.
    @State var strumChords: StrumChordSheet
    /// How a **Scales** drill authors its content: the generative box picker or the hand-drawn canvas
    /// (the custom-scale surface). Seeded from the stored content — a Scales exercise already holding a
    /// `.custom` drill opens in draw mode. Only meaningful for the scales template.
    @State var scaleMode: AuthoringMode
    /// How a **run-family** drill (warm-up/picking/legato/fingerstyle) authors its content: the
    /// generative `FretboardRunEditor` or the same hand-drawn canvas. Seeded from the stored content —
    /// a run exercise already holding a `.custom` drill opens in draw mode. Only meaningful for `.run`.
    @State var runMode: AuthoringMode
    /// How an **Arpeggios** drill authors its content: the generative `ArpeggioRunEditor` chord-tone box
    /// picker or the same hand-drawn canvas (ADR 0107). Seeded from the stored content — an arpeggio
    /// exercise already holding a `.custom` drill opens in draw mode. Only meaningful for `.arpeggio`.
    @State var arpeggioMode: AuthoringMode
    /// Which shape an Arpeggios drill generates (ADR 0313 D2): the box or triads, seeded from the stored
    /// content so a Triads run opens on Triads. Only meaningful for `.arpeggio`, and only on guitar.
    @State var arpeggioShape: ArpeggioShape
    /// The Triads run (ADR 0313), seeded from the stored content or, with none, the run D10 describes.
    @State var triads: TriadRun
    /// The box this sheet opened with, and whether it was saved with the exercise rather than seeded. Together
    /// they say whether switching to Triads carries the box's key (`carriesBoxKey`).
    private let seededBox: ArpeggioRun
    private let openedOnABox: Bool
    /// A rhythm change awaiting the player's answer (ADR 0121) — set on Done, cleared by either
    /// answer. While it's non-`nil` nothing has been written.
    @State private var pendingRhythmChange: RhythmChangePrompt?
    /// The stored content was written by a newer version and this one can't read it (ADR 0313 D4). The
    /// sheet then says so in place of an editor, and Done writes nothing.
    private let contentIsUnreadable: Bool

    init(exercise: Exercise) {
        self.exercise = exercise
        contentIsUnreadable = exercise.hasUnreadableContent
        _strum = State(initialValue: exercise.strumPattern
                       ?? .downstrokes(beatsPerBar: exercise.beatsPerBar))
        let content = exercise.fretboardContent
        _run = State(initialValue: content?.runValue ?? exercise.template.starterRun)
        _scale = State(initialValue: content?.scaleValue ?? .aMinorPentatonic)
        _arpeggio = State(initialValue: content?.arpeggioValue ?? .aMinorSeventh)
        seededBox = content?.arpeggioValue ?? .aMinorSeventh
        openedOnABox = content?.arpeggioValue != nil
        _triads = State(initialValue: content?.triadsValue ?? .starter)
        _arpeggioShape = State(initialValue: ArpeggioShape(content: content))
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
                if contentIsUnreadable {
                    NewerVersionNotice()
                } else {
                    switch exercise.template.bespokeEditor {
                    case .strumming?: strummingSection
                    case .run?: runSection
                    case .scale?: scaleSection
                    case .arpeggio?: arpeggioSection
                    case .chords?: chordsSection
                    case .strumChords?: strumChordsSection
                    case .fretboardGrid?: fretboardSection
                    // A freeform block's payload is prose, and prose is edited where it's read — the
                    // detail sheet's Instructions field (ADR 0136 F2a). It has no *shape*, and it never
                    // reaches this sheet in practice: the only door is `ExerciseRunView`, which
                    // `ExerciseRunScreen` never routes a freeform block to. Handled anyway rather than
                    // left to `nil`, so the case is answered where the question is asked.
                    case .freeform?, nil: EmptyView()
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Edit shape")
            .navigationBarTitleDisplayMode(.inline)
            .tint(PocketColor.practice)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { done() }
                        .disabled(!canCommit)
                }
            }
            .rhythmChangePrompt($pendingRhythmChange,
                                onKeep: { resolveRhythmChange(keepingNoteSpeed: true) },
                                onReMeasure: { resolveRhythmChange(keepingNoteSpeed: false) })
        }
    }

    /// Whether Done may write. The run editor's finger pattern is clearable to empty now (that is what
    /// lets it start on a finger other than 1) and an empty one expands to a drill with no notes, so it
    /// must not be *saved*. Mirrors `ConfigureExerciseForm.canCreate`; swipe-to-dismiss still escapes.
    private var canCommit: Bool {
        exercise.template.bespokeEditor != .run || runMode == .draw || !run.fingers.isEmpty
    }

    // MARK: - Rhythm changes (ADR 0121)

    /// Commit on Done — unless the edit moves the drill's **rhythm** away from the one the command
    /// tempo was measured in, in which case the sheet stays up until the player answers for it.
    /// Nothing is written before the answer: a half-applied change (new shape, unresolved command) is
    /// exactly the silent revaluation this exists to prevent.
    private func done() {
        guard !contentIsUnreadable else { return dismiss() }
        if let prompt = RhythmChangePrompt(exercise: exercise, movingTo: editedNoteRate ?? 0,
                                           range: StandaloneMetronomeEngine.bpmRange) {
            pendingRhythmChange = prompt
            return
        }
        commitAll()
        dismiss()
    }

    /// Apply the player's answer, then commit the shape edit itself. The tempo move happens **first**
    /// so `keepNoteSpeed` reads the old binding while it's still the stored truth; committing the
    /// content afterwards is what makes the new rhythm current.
    private func resolveRhythmChange(keepingNoteSpeed keep: Bool) {
        let newPerBeat = editedNoteRate ?? 0
        let range = StandaloneMetronomeEngine.bpmRange
        if keep {
            exercise.keepNoteSpeed(movingTo: newPerBeat, range: range)
        } else {
            exercise.reMeasureCommand(movingTo: newPerBeat, range: range)
        }
        pendingRhythmChange = nil
        commitAll()
        haptic(.medium)
        dismiss()
    }

    private func commitAll() {
        commitStrum(); commitFretboard(); commitChords(); commitStrumChords()
        // Re-bind after the content lands: a drill whose rhythm changed without revaluing anything
        // (no measured command, or none bound) still needs its binding to match what it now plays.
        exercise.bindCommandRhythmToContent()
        try? modelContext.save()
    }

    /// The rhythm the **edited** content states, before it's committed — the value the change is
    /// detected against. Mirrors `commitFretboard`'s editor switch; a template whose content states
    /// no rhythm reports the drill's own, so it registers as unchanged.
    private var editedNoteRate: Int? {
        switch exercise.template.bespokeEditor {
        case .strumming?: strum.slotsPerBeat
        case .strumChords?: strumChords.strumPattern.slotsPerBeat
        case .run?: runMode == .draw ? customDrill.notesPerBeat : run.notesPerBeat
        case .scale?: scaleMode == .draw ? customDrill.notesPerBeat : scale.notesPerBeat
        case .arpeggio?: arpeggioMode == .draw ? customDrill.notesPerBeat : generatedArpeggio.notesPerBeat
        case .fretboardGrid?: customDrill.notesPerBeat
        // Neither chords nor freeform states a rhythm, so both report the drill's own and register
        // as unchanged.
        case .chords?, .freeform?, nil: exercise.notesPerBeat
        }
    }

    // MARK: - Helpers

    /// What an Arpeggios drill generates: triads when Triads is chosen on a guitar drill (ADR 0313 D2),
    /// the box otherwise.
    var generatedArpeggio: FretboardContent {
        arpeggioShape == .triads && exercise.instrument == .guitar ? .triads(triads) : .arpeggio(arpeggio)
    }

    /// Whether switching to Triads carries the box's key (ADR 0313 D2): the box was saved with the
    /// exercise, or has been changed here. The A minor 7 seeded for a drill that held something else isn't
    /// a box anyone chose.
    var carriesBoxKey: Bool { openedOnABox || arpeggio != seededBox }

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
        // An Arpeggios drill writes its generated box or triads or, in draw mode, the custom drill.
        case .arpeggio: content = arpeggioMode == .draw ? .custom(customDrill) : generatedArpeggio
        case .fretboardGrid: content = .custom(customDrill)
        case .strumming, .chords, .strumChords, .freeform: return
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
