import SwiftData
import SwiftUI

/// The ⓘ sheet's **Folders** section (ADR 0210 D9) — where a drill is filed, and the door to
/// changing it.
///
/// Replaces the tag chips that used to sit under the description. Those chips were readable and
/// nothing else: `Exercise.tags` had no browse surface, no filter, and the library search did not
/// even look at them — the state ADR 0033 named as *"a grouping you can't filter by is just a
/// note"*. The tags themselves are not lost; `ExerciseFolderBackfill` copied every one into a folder
/// (D7), and the column is retired in place rather than removed.
///
/// Its own file for the reason `+Share` has one: the sheet sits against the 400-line cap.
extension ExerciseDetailSheet {

    /// Where this drill is filed, and **Add to folder…**.
    ///
    /// A drill can sit in several folders at once (D1/D2), so this is a list rather than a picker
    /// with one answer — and the footer says so, because "folder" is a word that borrows the
    /// expectation of *move*, which is the one expectation this design does not honour.
    var foldersSection: some View {
        Section {
            if exercise.folders.isEmpty {
                Text("Not in any folder.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
            } else {
                FlowLayout(spacing: 6) {
                    ForEach(exercise.folders, id: \.self) { path in
                        Text(FolderPath.leaf(path))
                            .font(.futura(.caption, weight: .semibold))
                            .foregroundStyle(PocketColor.practice)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(PocketColor.practice.opacity(0.16)))
                            // The leaf is what you read; the trail is what tells two *Warm-ups*
                            // apart, so it belongs to the label rather than the chip.
                            .accessibilityLabel(path)
                    }
                }
                .padding(.vertical, 2)
            }
            Button {
                filingFolders = true
            } label: {
                Label("Add to folder…", systemImage: "folder.badge.plus")
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(PocketColor.practice)
            }
        } header: {
            Text("Folders")
        } footer: {
            Text("Group drills however you like — by grade, by technique, by student. "
                 + "One drill can sit in as many folders as you want.")
        }
    }

    /// The shared picker, presented from the sheet's top level.
    var foldersPicker: some View {
        FolderPickerSheet(itemName: exercise.name.isEmpty ? "Untitled" : exercise.name,
                          current: exercise.folders,
                          namespace: PracticeFolderStore.namespace(in: modelContext),
                          onAdd: { PracticeFolderStore.file(exercise, into: $0, in: modelContext) },
                          onRemove: { exercise.folders = FolderPath.removing($0, from: exercise.folders) },
                          onCreate: { name in
            guard let created = PracticeFolderStore.createFolder(named: name, at: "",
                                                                 in: modelContext) else { return }
            Analytics.send(.folderCreated(depth: FolderPath.segments(created).count))
            PracticeFolderStore.file(exercise, into: created, in: modelContext)
        })
    }
}
