import SwiftData
import SwiftUI

/// The song library's **list body** — its grouped, collapsible sections and each row's actions
/// (ADR 0035; collapse from the v2 close-out Slice 5). Split out of `LibraryView` when the collapse
/// wiring pushed that file past the 400-line `--strict` cap; the members it reads drop `private`
/// for the same reason `RoutineDetailView`'s do.
extension LibraryView {

    var groupedList: some View {
        List {
            ForEach(sections, id: \.title) { section in
                CollapsibleLibrarySection(title: section.title,
                                          count: section.items.count,
                                          isExpanded: expansion(of: section.title)) {
                    ForEach(section.items) { song in
                        NavigationLink {
                            WaveformPracticeView(song: song, context: context)
                        } label: {
                            SongCard(song: song)
                        }
                        .listRowBackground(PocketColor.background)
                        // Hold a card for its actions; swipe still offers a quick Delete. Tap opens
                        // the song for practice. No favourite — `Song` has no pin (ADR 0119 covers
                        // exercises, loops and routines), which is exactly why the shared modifier
                        // takes it as an optional.
                        .pocketRowActions(displayName(song),
                                          tint: PocketColor.active,
                                          menu: menuItems(for: song),
                                          delete: deletion(for: song))
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    /// Whether a section shows its songs. Collapse is stored **per grouping key**: this library
    /// re-buckets on demand, and "A" under Artist is a different section from "A" under Title —
    /// sharing one collapse between them would shut a bucket the player never touched. A live
    /// search forces every section open, so a query can't match a song inside a collapsed bucket
    /// and read as a search that found nothing.
    func expansion(of title: String) -> Binding<Bool> {
        Binding(get: {
            LibrarySectionExpansion.isExpanded(title, in: collapsedSections,
                                               scope: grouping.rawValue,
                                               searching: !searchText.isEmpty)
        }, set: {
            collapsedSections = LibrarySectionExpansion.setting(title, expanded: $0,
                                                                in: collapsedSections,
                                                                scope: grouping.rawValue)
        })
    }

    func displayName(_ song: Song) -> String {
        song.title.isEmpty ? "Untitled song" : song.title
    }

    /// A song's long-press actions (Slice 3): the read-first overview, and the metadata editor.
    func menuItems(for song: Song) -> [PocketRowMenuItem] {
        [PocketRowMenuItem("Details", systemImage: "info.circle") { detailsSong = song },
         PocketRowMenuItem("Edit", systemImage: "pencil") { editingSong = song }]
    }

    /// Deleting a song takes its loops, markers and journal with it (cascade), so the Undo window
    /// the shared coordinator adds matters more here than anywhere else. Keyed on
    /// `persistentModelID` — `Song` is the one list model with no business `uid`.
    ///
    /// **It also deletes the audio (ADR 0182)**, via `SongDeletion` — this was the only song-delete
    /// path in the app and it was a bare `context.delete`, so every song ever deleted left its
    /// full-size copy behind forever. Safe against Undo: the coordinator defers `perform` until the
    /// window closes, so an undone delete never reaches this at all.
    func deletion(for song: Song) -> PocketRowDelete {
        PocketRowDelete(id: song.persistentModelID, name: displayName(song)) {
            SongDeletion.perform(song) { context.delete(song) }
        }
    }
}
