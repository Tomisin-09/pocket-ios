import SwiftUI

/// What a shared routine holds, shown **before** it lands (ADR 0188 D9).
///
/// The alternative is to import and then report, which delivers the same information after the point
/// where the player could have said no. That matters more on this door than on any other surface in
/// the app: the file was written by somebody else, on a device this one knows nothing about, and the
/// two things a player most wants to know — is this the routine I was sent, and what won't work here
/// — are both answerable before a single row is written.
///
/// Reads every count and label off `ReceivedRoutine` rather than off the payload, so the summary
/// shown here and the routine that lands cannot disagree.
struct ReceivedRoutinePreviewSheet: View {
    let received: ReceivedRoutine
    /// Write it. The sheet doesn't own the store — the host does, because tap-to-open can arrive with
    /// no screen of the app's own on top.
    let onAdd: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    tallyRow("Blocks", received.blockCount, "list.number")
                    tallyRow("Exercises", received.exerciseCount, "guitars")
                } header: {
                    Text(received.displayName)
                } footer: {
                    Text("Sent from Red Moon \(received.appVersion) on "
                         + received.exportedAt.formatted(date: .abbreviated, time: .shortened)
                         + ". Adding it makes your own copy — nothing in your library is changed or "
                         + "replaced.")
                }

                if !received.routine.notes.isEmpty {
                    Section("Notes") {
                        Text(received.routine.notes)
                            .font(.futura(.body))
                            .foregroundStyle(PocketColor.textPrimary)
                            .listRowBackground(PocketColor.background)
                    }
                }

                // Only when there is something to say. A routine of exercise and rest blocks crosses
                // whole, and a section headed "Won't come across" over an empty list would invent a
                // problem the file doesn't have.
                if !received.placeholderLabels.isEmpty {
                    Section {
                        ForEach(Array(received.placeholderLabels.enumerated()), id: \.offset) { _, label in
                            Label(label, systemImage: "questionmark.circle")
                                .font(.futura(.body))
                                .foregroundStyle(PocketColor.textSecondary)
                                .listRowBackground(PocketColor.background)
                        }
                    } header: {
                        Text("Won’t come across")
                    } footer: {
                        Text("These blocks played the sender's own song files, which stay on their "
                             + "device. The blocks still arrive — named, and in their place in the "
                             + "sitting — for you to point at your own material.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Add this routine?")
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

    /// One tally row — a count with its icon, right-aligned on tabular digits, matching
    /// `CollectionSessionSheet`'s pool tally.
    private func tallyRow(_ label: String, _ count: Int, _ icon: String) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.futura(.body))
                .foregroundStyle(PocketColor.textPrimary)
            Spacer()
            Text("\(count)")
                .font(.futura(.body).monospacedDigit())
                .foregroundStyle(PocketColor.textSecondary)
        }
        .listRowBackground(PocketColor.background)
    }
}

#Preview("Received routine — with placeholders") {
    // Built through the real record makers on uninserted models, so the preview shows the shapes the
    // door actually produces rather than a hand-written literal that can drift from them.
    let drill = Exercise(name: "Spider Walk")
    let routine = Routine(name: "Tuesday warm-up")
    routine.notes = "Slow hands first. Don’t chase the tempo."
    routine.items = [RoutineItem.item(drill, order: 0), RoutineItem.rest(order: 1)]
    return ReceivedRoutinePreviewSheet(
        received: ReceivedRoutine(routine: ArchiveBuilder.routineRecord(routine),
                                  exercises: [ArchiveBuilder.exerciseRecord(drill)],
                                  placeholders: [SharedBlockPlaceholder(itemUID: UUID(),
                                                                        label: "Chorus — Slow Bend")],
                                  appVersion: "1.2 (7)", exportedAt: .now),
        onAdd: {})
        .preferredColorScheme(.dark)
}
