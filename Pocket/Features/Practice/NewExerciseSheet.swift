import SwiftData
import SwiftUI

/// What a confirmed create produces — passed to `onCreate` so the caller inserts the model through
/// the shared `commandAnchored` factory. Bundles the chosen `template` (immutable after this) and
/// its authored `strum` payload (only for a strumming template) alongside the tempo + meter.
struct NewExercisePlan {
    let name: String
    let command: Int
    let signature: TimeSignature
    let template: ExerciseTemplate
    /// The instrument this drill is fixed to (ADR 0116) — seeded from the profile, overridable via the
    /// create step's Guitar/Bass control. Rides onto the created `Exercise`.
    let instrument: Instrument
    /// The authored strum pattern for a strumming template; `nil` for every other template.
    let strum: StrumPattern?
    /// The authored fretboard content — a generated run or a custom drill — for a fretboard-family
    /// template; `nil` for every other template.
    let fretboard: FretboardContent?
    /// The authored chord progression for a Chords template; `nil` for every other template.
    let chords: ChordProgression?
    /// The authored strum-chord sheet for a Strum & Chords template; `nil` for every other template.
    let strumChords: StrumChordSheet?
    /// The player's own written instructions — the **entire content** of a freeform block (ADR 0136
    /// F2), empty for every other template. Unlike the payloads above this is a plain stored attribute
    /// (`Exercise.notes`, which has existed unread since it was added), so it rides onto the model at
    /// insert rather than needing a relationship's after-the-insert dance.
    var notes: String = ""
    /// The player's declaration that a freeform block needs no instrument (ADR 0139 O6). Always
    /// `false` for every other template — the app models their content, and all of it wants the
    /// guitar in your hands.
    var awayFromInstrument = false
    /// The songs this drill is *for* (ADR 0111), picked on the configure step. Carried on the plan
    /// rather than assigned during authoring because `linkedSongs` is a **relationship**: it can only
    /// be set once the `Exercise` is in a context, so every host attaches these *after* its
    /// `insert` (the same ordering constraint `UnitDuplication` documents). Empty for a drill that
    /// isn't tied to any song, which is the common case.
    let songs: [Song]
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
    /// The instrument the create step opens on (ADR 0116) — the profile's preferred instrument, defaulting
    /// to guitar so an untouched install is unchanged.
    var defaultInstrument: Instrument = .guitar
    /// Songs pre-ticked in the configure step's link picker (ADR 0111). Empty for the two original
    /// hosts; the song player's tempo-carry gateway (ADR 0170) passes the song the carried tempo was
    /// read off, so a drill born out of a song arrives already tied to it.
    var initialSongs: [Song] = []
    /// Called with the assembled plan when the user confirms. The caller inserts the model.
    let onCreate: (NewExercisePlan) -> Void

    /// **What the picker step hands to the configure step** — the template *and* the instrument it was
    /// chosen on, travelling together as the navigation item.
    ///
    /// The instrument used to be read off `@State` from inside the `navigationDestination` closure. That
    /// silently never worked: SwiftUI registers a dependency only for values read *during* body
    /// evaluation, and the picker receives `$instrument` (a binding — not a read of the value), so
    /// changing the segment invalidated nothing. The destination closure kept the snapshot from the one
    /// body evaluation that ran when the sheet opened, where the instrument is still the profile
    /// default — so the Settings instrument overrode the control in **both** directions and every
    /// fretboard drill drew the profile's neck. Carrying the value on the item means it is read at tap
    /// time, by the on-screen picker, and can't go stale.
    ///
    /// It is also the navigation **identity**, so picking the same template again after switching
    /// instrument pushes a fresh form rather than reusing the previous one's seeded `@State`.
    struct TemplateChoice: Hashable {
        let template: ExerciseTemplate
        let instrument: Instrument
    }

    @Environment(\.dismiss) private var dismiss
    @State private var chosen: TemplateChoice?
    /// Whether this sheet actually produced a drill. Drives the abandonment signal on disappear
    /// (ADR 0120) — reported from here rather than from each host's `onDismiss` because this is the
    /// only place that knows *which* template was being configured when the player walked away, and
    /// one edit covers both hosts (the library's + button and the automator's save seam).
    @State private var created = false
    /// The Guitar/Bass axis for the drill being created (ADR 0116 S6) — chosen on the picker step, then
    /// handed to the configure form as its fixed instrument. Seeded from the profile's `defaultInstrument`.
    @State private var instrument: Instrument

    init(initialCommand: Int = StandaloneMetronomeEngine.defaultCommandBPM,
         initialSignature: TimeSignature = .standard,
         fixedTemplate: ExerciseTemplate? = nil,
         defaultInstrument: Instrument = .guitar,
         initialSongs: [Song] = [],
         onCreate: @escaping (NewExercisePlan) -> Void) {
        self.initialCommand = initialCommand
        self.initialSignature = initialSignature
        self.fixedTemplate = fixedTemplate
        self.defaultInstrument = defaultInstrument
        self.initialSongs = initialSongs
        self.onCreate = onCreate
        _instrument = State(initialValue: defaultInstrument)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let fixedTemplate {
                    ConfigureExerciseForm(template: fixedTemplate, initialCommand: initialCommand,
                                          initialSignature: initialSignature,
                                          initialInstrument: instrument, initialSongs: initialSongs,
                                          create: create)
                } else {
                    ExerciseTemplatePicker(instrument: $instrument) { template, instrument in
                        chosen = TemplateChoice(template: template, instrument: instrument)
                    }
                }
            }
            .navigationDestination(item: $chosen) { choice in
                ConfigureExerciseForm(template: choice.template, initialCommand: initialCommand,
                                      initialSignature: initialSignature,
                                      initialInstrument: choice.instrument, initialSongs: initialSongs,
                                      create: create)
            }
            .tint(PocketColor.practice)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        // Covers every way out — Cancel, the swipe-down, and a host dismissing the sheet — because
        // all of them are the same thing to the player: they opened the create flow and got nothing.
        .onDisappear {
            guard !created else { return }
            Analytics.send(.exerciseAuthoringAbandoned(template: chosen?.template ?? fixedTemplate))
        }
    }

    private func create(_ plan: NewExercisePlan) {
        created = true
        onCreate(plan)
        dismiss()
    }
}

#Preview("New exercise — picker") {
    NewExerciseSheet { _ in }
        .modelContainer(NewExerciseSheet.previewContainer())
}

#Preview("New exercise — fixed basic") {
    NewExerciseSheet(fixedTemplate: .basic) { _ in }
        .modelContainer(NewExerciseSheet.previewContainer())
}

private extension NewExerciseSheet {
    /// The configure step queries songs for its link picker (ADR 0111), so both previews need a
    /// container — the picker preview too, since navigating to the second step would otherwise trap.
    static func previewContainer() -> ModelContainer {
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(for: Song.self, Exercise.self, Loop.self,
                                           configurations: .init(isStoredInMemoryOnly: true))
        container.mainContext.insert(Song.sample())
        return container
    }
}
