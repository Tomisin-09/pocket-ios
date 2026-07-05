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

    private let range = StandaloneMetronomeEngine.bpmRange

    init(template: ExerciseTemplate, initialCommand: Int, initialSignature: TimeSignature,
         create: @escaping (NewExercisePlan) -> Void) {
        self.template = template
        self.initialCommand = initialCommand
        self.initialSignature = initialSignature
        self.create = create
        _command = State(initialValue: initialCommand)
        _signature = State(initialValue: initialSignature)
        let seed = template.defaultStrumPattern ?? .downstrokes(beatsPerBar: initialSignature.beats)
        _strum = State(initialValue: seed.resized(slotsPerBeat: seed.slotsPerBeat,
                                                  beatsPerBar: initialSignature.beats))
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func clampCommand(_ value: Int) -> Int {
        min(range.upperBound, max(range.lowerBound, value))
    }

    var body: some View {
        Form {
            Section("Name") {
                TextField(namePlaceholder, text: $name)
            }
            if template.hasBespokeEditor { strumSection }
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
        }
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Create") { create(plan) }
                    .disabled(trimmedName.isEmpty)
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

    private var namePlaceholder: String {
        switch template {
        case .strumming: return "e.g. Folk strum"
        case .scales: return "e.g. A minor pentatonic"
        case .chords: return "e.g. G–C–D changes"
        default: return "e.g. Spider"
        }
    }

    private var plan: NewExercisePlan {
        NewExercisePlan(name: trimmedName, command: command, signature: signature,
                        template: template, strum: template.hasBespokeEditor ? strum : nil)
    }
}

#Preview("New exercise — picker") {
    NewExerciseSheet { _ in }
}

#Preview("New exercise — fixed basic") {
    NewExerciseSheet(fixedTemplate: .basic) { _ in }
}
