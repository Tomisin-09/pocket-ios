import SwiftUI

/// A set's **songs** in the long-term goal editor (ADR 0299 D1): the ones chosen, then a row that opens
/// the library to add or remove them. Where *Play a specific song* has `GoalTargetSongSection` and one
/// song, a set has this and several.
///
/// **Unordered** (D3): the chosen songs list by title, because there is no running order to keep.
/// Selection is by `Song.sourceID`, the form the goal stores.
struct GoalSetSongsSection: View {
    let songs: [Song]
    @Binding var songIDs: Set<String>

    /// The chosen songs that are still in the library, by title.
    private var chosen: [Song] {
        songs.filter { songIDs.contains($0.sourceID) }
            .sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    var body: some View {
        Section {
            if songs.isEmpty {
                Text("Add songs to your library to put them in a set.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else {
                ForEach(chosen, id: \.sourceID) { song in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(song.title.isEmpty ? "Untitled" : song.title)
                            .font(.futura(.body))
                            .foregroundStyle(PocketColor.textPrimary)
                        if !song.artist.isEmpty {
                            Text(song.artist)
                                .font(.futura(.caption))
                                .foregroundStyle(PocketColor.textSecondary)
                        }
                    }
                    .listRowBackground(PocketColor.background)
                }
                NavigationLink {
                    SearchableMultiPickerList(
                        title: "Songs",
                        items: songs.map {
                            PickerItem(value: $0.sourceID, title: $0.title.isEmpty ? "Untitled" : $0.title,
                                       context: $0.artist)
                        },
                        selection: $songIDs)
                } label: {
                    Label(chosen.isEmpty ? "Choose songs" : "Add or remove songs",
                          systemImage: "music.note.list")
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.practice)
                }
                .listRowBackground(PocketColor.background)
            }
        } header: {
            Text("Songs")
        } footer: {
            Text("Each song's loops and a play-through are scheduled in turn, the one you've left longest "
                 + "first. There's no running order.")
                .font(.futura(.caption))
        }
    }
}
