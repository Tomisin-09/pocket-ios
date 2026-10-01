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
    /// What each song that came with it will be called here (ADR 0236 D5), in `received.songs`' order.
    var songTitles: [String] = []
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
                    Text(provenance)
                }

                if !received.songs.isEmpty { songsSection }

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
                        Text("These blocks played songs that weren’t sent with the routine. The blocks "
                             + "still arrive — named, and in their place in the sitting — for you to point "
                             + "at your own material.")
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

    /// The songs that came with it (ADR 0236 D6), each under the name it lands with, and a line for any
    /// that lands as a copy beside a song the library already has.
    private var songsSection: some View {
        Section {
            ForEach(Array(received.songs.enumerated()), id: \.offset) { index, song in
                let title = songTitles.indices.contains(index) ? songTitles[index] : song.displayTitle
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Label(title, systemImage: "music.note")
                            .font(.futura(.body))
                            .foregroundStyle(PocketColor.textPrimary)
                        Spacer()
                        Text(song.record.loops.count == 1 ? "1 loop" : "\(song.record.loops.count) loops")
                            .font(.futura(.body).monospacedDigit())
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                    if title != song.displayTitle {
                        Text("You have a song called \(song.displayTitle). This one goes beside it.")
                            .font(.futura(.footnote))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                }
                .listRowBackground(PocketColor.background)
            }
        } header: {
            Text("Songs")
        } footer: {
            Text("Each comes with its audio, loops and markers, and its blocks play it. The sender’s pieces, "
                 + "mastery and practice history stayed with them.")
        }
    }

    /// *Sent by Tomisin from Red Moon 1.3 on …* (ADR 0236 D7), or *Sent from…* with no name in the file.
    private var provenance: String {
        let who = received.senderName.map { "Sent by \($0) from" } ?? "Sent from"
        return "\(who) Red Moon \(received.appVersion) on "
            + received.exportedAt.formatted(date: .abbreviated, time: .shortened)
            + ". Adding it makes your own copy — nothing in your library is changed or replaced."
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
