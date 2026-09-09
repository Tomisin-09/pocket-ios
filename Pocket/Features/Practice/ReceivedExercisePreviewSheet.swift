import SwiftUI

/// What a shared drill holds, shown **before** it lands (ADR 0209 D6) — the exercise twin of
/// `ReceivedRoutinePreviewSheet`, and the same argument: importing and then reporting delivers the
/// same information after the point where the player could have said no. That matters most on this
/// door, because the file was written by somebody else on a device this one knows nothing about.
///
/// Reads every value off `ReceivedExercise` rather than off the record, so the summary shown here and
/// the drill that lands cannot disagree.
///
/// **No "Won't come across" section, unlike the routine's.** That one exists because a routine would
/// otherwise arrive silently *shorter* — a block whose loop could not travel leaves a visible gap, so
/// the file names it (ADR 0188 D4). A drill's shape arrives whole: its reference links and song links
/// are dropped, and their absence leaves no hole to explain. The footer says once, plainly, what a
/// shared drill never carries, and nothing in the file has to enumerate it.
struct ReceivedExercisePreviewSheet: View {
    let received: ReceivedExercise
    /// Write it. The sheet doesn't own the store — the host does, because tap-to-open can arrive with
    /// no screen of the app's own on top.
    let onAdd: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // The template is skipped rather than guessed when the file names one this build
                    // does not know (`ReceivedExercise.template`) — the confirmation screen is the
                    // last place that should tell the player something untrue about the file.
                    if let template = received.template {
                        detailRow("Type", template.displayName, "square.grid.2x2")
                    }
                    detailRow("Feel", received.feel, "metronome")
                    detailRow("Tempo", received.tempoPlan, "speedometer")
                } header: {
                    Text(received.displayName)
                } footer: {
                    // Provenance and what travelled, in one place. Said here rather than left to be
                    // discovered: the two things a receiver would otherwise wonder about are the
                    // sender's numbers (which never cross — ADR 0070's rule holds through a side door
                    // too) and their links, whose files live on their device (ADR 0148).
                    Text("Sent from Red Moon \(received.appVersion) on "
                         + received.exportedAt.formatted(date: .abbreviated, time: .shortened)
                         + ". Adding it makes your own copy — nothing in your library is changed or "
                         + "replaced. It arrives unpractised: the drill, its rhythm and its tempo "
                         + "plan come across, but the sender's own ratings, history, linked songs "
                         + "and reference links stay with them.")
                }

                if !received.exercise.notes.isEmpty {
                    Section("Description") {
                        Text(received.exercise.notes)
                            .font(.futura(.body))
                            .foregroundStyle(PocketColor.textPrimary)
                            .listRowBackground(PocketColor.background)
                    }
                }

                if !received.exercise.tags.isEmpty {
                    Section("Tags") {
                        Text(received.exercise.tags.joined(separator: ", "))
                            .font(.futura(.body))
                            .foregroundStyle(PocketColor.textSecondary)
                            .listRowBackground(PocketColor.background)
                    }
                }

            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Add this exercise?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd()
                        dismiss()
                    }
                    .tint(PocketColor.practice)
                }
            }
        }
    }

    /// One labelled fact — the read-only sibling of `ReceivedRoutinePreviewSheet.tallyRow`, which
    /// counts things. A drill has no counts worth showing; it has a shape.
    private func detailRow(_ label: String, _ value: String, _ icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.futura(.body))
                .foregroundStyle(PocketColor.textPrimary)
            Spacer()
            Text(value)
                .font(.futura(.body))
                .foregroundStyle(PocketColor.textSecondary)
        }
        .listRowBackground(PocketColor.background)
    }
}

#Preview("Received exercise") {
    // Built through the real record maker on an uninserted model, so the preview shows the shape the
    // door actually produces rather than a hand-written literal that can drift from it.
    let drill = Exercise(name: "Spider Walk", currentTempo: 60, targetTempo: 120)
    drill.notes = "One finger per fret. Stop the moment it buzzes."
    drill.tags = ["warm-up", "left hand"]
    return ReceivedExercisePreviewSheet(
        received: ReceivedExercise(exercise: SharedPracticeBuilder.shareable(drill),
                                   appVersion: "1.2 (7)", exportedAt: .now),
        onAdd: {})
        .preferredColorScheme(.dark)
}
