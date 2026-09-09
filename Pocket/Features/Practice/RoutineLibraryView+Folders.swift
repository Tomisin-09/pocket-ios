import SwiftData
import SwiftUI

/// The **folder axis** on the Routines library (ADR 0210 S1) — and the first grouping this library
/// has ever had. Until now a Routines list was flat however long it got: `Routine` carried no label
/// field at all, where `Exercise` at least had tags.
///
/// The same namespace the Exercises library browses (D3), so a *Beginner* folder is one folder with
/// two kinds of thing in it, and each library shows its own members. Split out for the file-length
/// reason `RoutineLibraryView+Row` already establishes.
extension RoutineLibraryView {

    /// Every folder the library knows about: marker paths and paths derived from members, ancestors
    /// included, from **both** models (D3/D4). Drawn from `@Query` so a new folder redraws the list.
    var folderNamespace: [String] {
        let fromMarkers = folderMarkers.flatMap { FolderPath.ancestry($0.path) }
        let fromRoutines = routines.flatMap { $0.folders.flatMap { FolderPath.ancestry($0) } }
        let fromDrills = exercises.flatMap { $0.folders.flatMap { FolderPath.ancestry($0) } }
        return FolderPath.normalized(fromMarkers + fromRoutines + fromDrills)
    }

    /// The routines at or below where the player is standing (D6b). At the root, the whole library.
    var scopedRoutines: [Routine] {
        presentRoutines.filter { FolderPath.contains($0.folders, within: folderBrowse.path) }
    }

    /// The immediate child folders here — S3's `CommonPrefixes` (D6b).
    var childFolders: [String] {
        FolderPath.children(of: folderBrowse.path, in: folderNamespace)
    }

    /// The folder rows, above the routine rows.
    ///
    /// **The count is routines**, not everything in the folder. A folder holding six drills and no
    /// sessions reads `0` here and `6` in the Exercises library, which is the honest reading of one
    /// namespace seen from two libraries: each shows its own members (D3).
    @ViewBuilder var folderRows: some View {
        if childFolders.isEmpty {
            // No folders anywhere yet: offer to make the first one, and only at the root — inside a
            // folder the ⋯ menu is the door, and a nag on every empty leaf would be a nag.
            if folderBrowse.path.isEmpty && !presentRoutines.isEmpty {
                Section {
                    FolderInviteRow(noun: "sessions") { folderBrowse.beginCreate() }
                        .listRowBackground(PocketColor.background)
                }
            }
        } else {
            CollapsibleLibrarySection(title: Self.foldersSectionTitle,
                                      count: childFolders.count,
                                      isExpanded: $foldersExpanded,
                                      icon: "folder") {
                ForEach(childFolders, id: \.self) { folder in
                    let count = presentRoutines.filter {
                        FolderPath.contains($0.folders, within: folder)
                    }.count
                    FolderRow(name: FolderPath.leaf(folder), itemCount: count,
                              countLabel: count == 1 ? "1 routine" : "\(count) routines") {
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

    /// The escape hatch (D6): clear the prefix, keep the query.
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

    /// **New folder…**, in the options menu — not on the nav bar, where nothing may vary in width
    /// (ADR 0126).
    ///
    /// **Not gated.** Making a folder is organising, not authoring: it mints no routine, and a free
    /// player whose library is a handful of drills is exactly who needs it least *and* who would
    /// read a padlock here as the app charging for tidiness.
    var newFolderButton: some View {
        Button {
            folderBrowse.beginCreate()
        } label: {
            Label("New folder…", systemImage: "folder.badge.plus")
        }
    }

    /// The shared picker (D9), bound to the routine being filed.
    @ViewBuilder var folderPicker: some View {
        if let routine = filing {
            FolderPickerSheet(itemName: routine.name.isEmpty ? "Untitled routine" : routine.name,
                              current: routine.folders,
                              namespace: folderNamespace,
                              onAdd: { PracticeFolderStore.file(routine, into: $0, in: context) },
                              onRemove: { routine.folders = FolderPath.removing($0, from: routine.folders) },
                              onCreate: { name in
                guard let created = PracticeFolderStore.createFolder(named: name, at: "",
                                                                     in: context) else { return }
                Analytics.send(.folderCreated(depth: FolderPath.segments(created).count))
                PracticeFolderStore.file(routine, into: created, in: context)
            })
        }
    }
}
