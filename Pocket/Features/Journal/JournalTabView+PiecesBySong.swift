import SwiftUI

/// The **Pieces** scope, grouped by song (ADR 0232 D20): the cross-song way into *Map the song*, which is
/// what ADR 0229 said this list would become once the map landed, rather than a second list in the Toolkit.
///
/// Under *All* a piece still sits on the day it last changed (ADR 0229 D2). Under *Pieces* there are no
/// day sections, so there are no months to offer and nowhere for **Jump to…** to land (`visibleDays`).
extension JournalTabView {

    /// Whether the feed is grouped by song rather than by day.
    var groupsBySong: Bool { scope == .pieces }

    /// One section per song, headed by the song with *Map the song* beside it. The heading is pinned while
    /// its pieces scroll, like a day's, so the way into the map stays in reach.
    @ViewBuilder var songSections: some View {
        ForEach(JournalSongPieces.group(items, order: sortOrder)) { group in
            Section {
                ForEach(group.pieces, id: \.loop.uid) { piece in
                    // The song is the heading, so the caption is the loop alone, and the stamp is the
                    // day: there is no day heading above it any more.
                    JournalPieceRow(piece: piece, ownerLabel: piece.loop.name.isEmpty ? "Loop" : piece.loop.name,
                                    onOpen: openAction(for: .piece(piece)), stamp: dayHeader(piece.date))
                        .listRowBackground(PocketColor.background)
                }
            } header: {
                JournalSongPiecesHeader(song: group.song,
                                        onMap: group.song == nil ? nil : {
                                            player.stop()
                                            mappingFrom = StableRef(value: group.lead)
                                        })
            }
        }
    }
}

/// A song's heading under the **Pieces** scope: its title and artist, and **Map the song** (ADR 0232
/// D20), which opens the map full screen as Song details does (D1).
struct JournalSongPiecesHeader: View {
    let song: Song?
    /// `nil` for pieces with no song, which have no map to open.
    let onMap: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.futura(.subheadline, weight: .semibold))
                    .foregroundStyle(PocketColor.textPrimary)
                    .lineLimit(2)
                if let artist = song?.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                        .lineLimit(1)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 8)
            if let onMap {
                Button(action: onMap) {
                    Label("Map the song", systemImage: "puzzlepiece")
                        .font(.futura(.caption, weight: .semibold))
                        .foregroundStyle(PocketColor.journal)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background { Capsule().fill(PocketColor.surfaceStandard) }
                        .fixedSize()
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens \(title)'s loops laid out where they play")
            }
        }
        // A song's title as the player wrote it: a List header is otherwise set in capitals on iOS 18.
        .textCase(nil)
        .padding(.vertical, 2)
    }

    private var title: String {
        guard let song else { return "No song" }
        return song.title.isEmpty ? "Untitled song" : song.title
    }
}
