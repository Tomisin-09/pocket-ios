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
    /// The exercise's strumming pattern, held locally and committed on Done (ADR 0065). Seeded from
    /// the stored payload (a strumming exercise always has one), falling back to a bar-matched
    /// downstrokes canvas defensively. Only surfaced/committed for a strumming template.
    @State private var strum: StrumPattern

    init(exercise: Exercise) {
        self.exercise = exercise
        _notes = State(initialValue: exercise.notes)
        _strum = State(initialValue: exercise.strumPattern
                       ?? .downstrokes(beatsPerBar: exercise.beatsPerBar))
    }

    var body: some View {
        NavigationStack {
            Form {
                templateSection
                descriptionSection
                temposSection
                feelSection
                routineSection
                if exercise.template.hasBespokeEditor { howToPlaySection }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(exercise.name.isEmpty ? "Exercise" : exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .tint(PocketColor.practice)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { commitNotes(); commitStrum(); dismiss() }
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

    // MARK: - Tempo anchors (read-only)

    private var temposSection: some View {
        Section {
            LabeledContent("Working") { bpmText(exercise.workingTempo) }
            LabeledContent("Command") {
                Text(exercise.hasMeasuredCommand ? "\(exercise.command) BPM" : "not yet measured")
                    .font(.pocketMono(.body))
                    .foregroundStyle(exercise.hasMeasuredCommand
                                     ? PocketColor.textPrimary : PocketColor.textSecondary)
            }
            LabeledContent("Reach") { bpmText(exercise.derivedTarget) }
        } header: {
            Text("Tempo")
        } footer: {
            Text("Command is the fastest you own it clean; working is the warm-up floor and reach is "
                 + "the goal above command. Tune these on the run screen.")
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

    // MARK: - How to play (strumming template editor, ADR 0065)

    /// The strumming template's authoring surface — the tap-to-edit `StrumPatternEditor` over the
    /// exercise's always-present pattern. No "remove" control: the template is immutable, so a
    /// strumming drill stays a strumming drill; you edit the pattern, you don't strip it.
    private var howToPlaySection: some View {
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

    // MARK: - Helpers

    private func bpmText(_ bpm: Int) -> some View {
        Text("\(bpm) BPM").font(.pocketMono(.body)).foregroundStyle(PocketColor.textPrimary)
    }

    /// Persist an edited description, trimmed. A no-op when unchanged, so opening and closing the
    /// sheet without touching the field never writes to the store.
    private func commitNotes() {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != exercise.notes else { return }
        exercise.notes = trimmed
        try? modelContext.save()
    }

    /// Persist an edited strum pattern on Done, only for a strumming template and only when it
    /// differs from what's stored (ADR 0065). Never touches the template itself (it's immutable).
    private func commitStrum() {
        guard exercise.template.hasBespokeEditor, strum != exercise.strumPattern else { return }
        exercise.setStrumPattern(strum)
        try? modelContext.save()
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
