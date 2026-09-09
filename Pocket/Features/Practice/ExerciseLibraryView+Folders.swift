import SwiftData
import SwiftUI

/// The **folder axis** on the Exercises library (ADR 0210 S1): the prefix walk, the folder rows, the
/// New-folder control and the picker.
///
/// Split out for the reason `RoutineLibraryView+Row` was — the view had reached the 400-line cap —
/// and along the same seam: what stays in `ExerciseLibraryView` decides which drills are on screen
/// and in what order; this decides *where in the tree you are standing*, which is the input to that.
/// The members are internal only because a same-module extension cannot see `private`.
extension ExerciseLibraryView {

    /// Every folder the library knows about: marker paths and paths derived from members, ancestors
    /// included, from **both** models (D3/D4).
    ///
    /// Drawn from `@Query` rather than `PracticeFolderStore.namespace(in:)` so that creating a
    /// folder redraws this screen — the store's fetch is for code that has no view to invalidate.
    var folderNamespace: [String] {
        let fromMarkers = folderMarkers.flatMap { FolderPath.ancestry($0.path) }
        let fromDrills = exercises.flatMap { $0.folders.flatMap { FolderPath.ancestry($0) } }
        let fromRoutines = routines.flatMap { $0.folders.flatMap { FolderPath.ancestry($0) } }
        return FolderPath.normalized(fromMarkers + fromDrills + fromRoutines)
    }

    /// The drills at or below where the player is standing (D6b). At the root this is the whole
    /// library, unchanged — which is what makes the axis additive to the screen as well as the
    /// schema.
    var scopedExercises: [Exercise] {
        presentExercises.filter { FolderPath.contains($0.folders, within: folderBrowse.path) }
    }

    /// The immediate child folders here — S3's `CommonPrefixes`, and the only part of the design
    /// that stays literally S3 (D6b).
    var childFolders: [String] {
        FolderPath.children(of: folderBrowse.path, in: folderNamespace)
    }

    /// The folder rows, above the template sections. Folders group by *intent*, templates (ADR 0068)
    /// by *kind* — orthogonal axes, so both survive and neither collapses the other.
    ///
    /// Shown even while a search finds nothing, so a query that matches a drill two folders down
    /// still leaves the way down visible.
    ///
    /// **Collapsible, using the same `CollapsibleLibrarySection` the template sections use**, and
    /// **closed until asked for** — see `foldersExpanded` for why the default is the opposite of the
    /// template sections'.
    @ViewBuilder var folderRows: some View {
        if !childFolders.isEmpty {
            CollapsibleLibrarySection(title: Self.foldersSectionTitle,
                                      count: childFolders.count,
                                      isExpanded: $foldersExpanded,
                                      icon: "folder") {
                ForEach(childFolders, id: \.self) { folder in
                    let count = presentExercises.filter {
                        FolderPath.contains($0.folders, within: folder)
                    }.count
                    FolderRow(name: FolderPath.leaf(folder), itemCount: count,
                              countLabel: count == 1 ? "1 exercise" : "\(count) exercises") {
                        folderBrowse.open(folder)
                    }
                    .listRowBackground(PocketColor.background)
                    .contextMenu {
                        Button {
                            folderBrowse.beginRename(of: folder)
                        } label: {
                            Label("Rename…", systemImage: "pencil")
                        }
                        Button(role: .destructive) {
                            folderBrowse.deleting = folder
                        } label: {
                            Label("Delete folder", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    /// The folder section's header.
    static var foldersSectionTitle: String { "Folders" }

    /// The one escape hatch (D6): a search inside a folder that finds nothing offers to clear the
    /// prefix and keep the query, so a player never concludes a drill is gone when they are merely
    /// standing somewhere else.
    @ViewBuilder var searchAllFoldersButton: some View {
        if !folderBrowse.path.isEmpty, !searchText.isEmpty {
            Button {
                folderBrowse.path = ""
                haptic(.light)
            } label: {
                Label("Search all folders", systemImage: "magnifyingglass")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.practice)
            }
            .listRowBackground(PocketColor.background)
        }
    }

    /// **New folder…**, in the options menu beside *Receive an exercise…* rather than on the nav bar
    /// — nothing on that bar may vary in width (ADR 0126), and this is a labelled verb.
    var newFolderButton: some View {
        Button {
            folderBrowse.beginCreate()
        } label: {
            Label("New folder…", systemImage: "folder.badge.plus")
        }
    }

    /// The shared picker (D9), bound to the drill being filed.
    @ViewBuilder var folderPicker: some View {
        if let exercise = filing {
            FolderPickerSheet(itemName: exercise.name.isEmpty ? "Untitled" : exercise.name,
                              current: exercise.folders,
                              namespace: folderNamespace,
                              onAdd: { PracticeFolderStore.file(exercise, into: $0, in: context) },
                              onRemove: { exercise.folders = FolderPath.removing($0, from: exercise.folders) },
                              onCreate: { name in
                guard let created = PracticeFolderStore.createFolder(named: name, at: "",
                                                                     in: context) else { return }
                Analytics.send(.folderCreated(depth: FolderPath.segments(created).count))
                PracticeFolderStore.file(exercise, into: created, in: context)
            })
        }
    }
}
