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

#Preview("New exercise — picker") {
    NewExerciseSheet { _ in }
}

#Preview("New exercise — fixed basic") {
    NewExerciseSheet(fixedTemplate: .basic) { _ in }
}
