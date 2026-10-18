import SwiftUI

extension SongDetailsSheet {
    /// The categories you open rather than glance at (ADR 0258), one row each, every row saying what is
    /// behind it (ADR 0162 D3) so the common visit ends here. Each pushes a screen inside this sheet's
    /// `NavigationStack`; each screen raises its own presentations.
    var categoriesSection: some View {
        Section {
            progressRow
            referencesRow
            audioFileRow
            // Read-only, and absent when empty, as the Collections section always was.
            if !song.collections.isEmpty { collectionsRow }
        }
    }

    private var progressRow: some View {
        NavigationLink { SongProgressScreen(song: song) } label: {
            HubRow(icon: "chart.line.uptrend.xyaxis", title: "Progress",
                   value: DetailSheetText.loops(song.loops.count))
        }
    }

    private var referencesRow: some View {
        NavigationLink { ReferencesScreen(owner: song, accent: PocketColor.library) } label: {
            HubRow(icon: "link", title: "References", value: song.referencesRowValue)
        }
    }

    /// Which file this song plays, and the way to change it (ADR 0152): the relink door that doesn't
    /// depend on the audio being broken. Its value is the File row's words, so *Missing* shows here
    /// without opening anything.
    private var audioFileRow: some View {
        NavigationLink { SongAudioScreen(song: song, replace: replace) } label: {
            HubRow(icon: "waveform", title: "Audio file", value: SongAudioLabel.describe(song))
        }
    }

    private var collectionsRow: some View {
        NavigationLink { SongCollectionsScreen(song: song) } label: {
            HubRow(icon: "tag", title: "Collections",
                   value: song.collections.joined(separator: ", "))
        }
    }
}
