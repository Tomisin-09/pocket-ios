import SwiftData
import SwiftUI

/// A reference sheet for one exercise (V1 feedback #2): the place to read — and lightly annotate —
/// what an exercise *is*, kept separate from the run-setup tuning. It surfaces an editable
/// **description** (the model's `notes`, which previously had no UI at all), the tempo anchors
/// (working / command / reach), the meter + subdivision, a read-only preview of the training
/// routine staircase, and a placeholder for the **animated fretboard guide** planned for a future
/// release. Reached from the exercise run screen's nav bar (ⓘ).
///
/// The description is the only editable field; it's committed to the model on Done / dismiss (a
/// no-op when unchanged) so a quick open-and-close never writes. Everything else is read-only —
/// the tempos and routine are tuned on the run screen, not here.
struct ExerciseDetailSheet: View {
    let exercise: Exercise

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var notes: String

    init(exercise: Exercise) {
        self.exercise = exercise
        _notes = State(initialValue: exercise.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                descriptionSection
                temposSection
                feelSection
                routineSection
                fretboardSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(exercise.name.isEmpty ? "Exercise" : exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .tint(PocketColor.practice)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { commitNotes(); dismiss() }
                }
            }
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

    // MARK: - Fretboard guide (future)

    private var fretboardSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "guitars.fill")
                    .font(.futura(.title3))
                    .foregroundStyle(PocketColor.practice)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fretboard guide")
                        .font(.futura(.subheadline, weight: .medium))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text("Animated fretboard walkthroughs are coming in a future update.")
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            .padding(.vertical, 2)
        } header: {
            Text("How to play")
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
}

#Preview("Exercise detail") {
    let exercise = Exercise(name: "Alternating picking", currentTempo: 70, commandTempo: 96,
                            tags: ["picking", "warmup"], notes: "Anchor the wrist; even down-up.")
    return ExerciseDetailSheet(exercise: exercise).preferredColorScheme(.dark)
}
