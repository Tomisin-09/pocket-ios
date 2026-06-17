import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The app root: the song library (ADR 0011 Slice 2). A simple list of songs to
/// open for practice, a `+` to import an audio file, and an empty state offering
/// import or the bundled demo. Replaces the temporary launch-into-first-song.
struct LibraryView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Song.title) private var songs: [Song]
    @State private var importing = false
    @State private var importError: String?
    @State private var editingSong: Song?

    var body: some View {
        NavigationStack {
            Group {
                if songs.isEmpty {
                    LibraryEmptyState(onImport: { importing = true }, onTryDemo: addDemo)
                } else {
                    songList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Songs")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { importing = true } label: { Image(systemName: "plus") }
                        .tint(PocketColor.active)
                        .accessibilityLabel("Import a song")
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.audio], onCompletion: handleImport)
            .alert("Couldn’t import", isPresented: importErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
            .sheet(item: $editingSong) { song in
                SongEditSheet(song: song)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var songList: some View {
        List {
            ForEach(songs) { song in
                NavigationLink {
                    WaveformPracticeView(song: song, context: context)
                } label: {
                    SongRow(song: song)
                }
                .listRowBackground(PocketColor.background)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) { context.delete(song) } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button { editingSong = song } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(PocketColor.active)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var importErrorBinding: Binding<Bool> {
        Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })
    }

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                try SongImporter.importSong(from: url, into: context)
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func addDemo() { context.insert(Song.sample()) }
}

/// A single library row: title, artist (when known), and proficiency.
private struct SongRow: View {
    let song: Song

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(song.title)
                    .font(.headline)
                    .foregroundStyle(PocketColor.textPrimary)
                if !song.artist.isEmpty {
                    Text(song.artist)
                        .font(.subheadline)
                        .foregroundStyle(PocketColor.textSecondary)
                }
            }
            Spacer(minLength: 8)
            if song.proficiency > 0 { ProficiencyDots(filled: song.proficiency) }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

/// Proficiency as up to five small dots (0–5), amber when filled.
private struct ProficiencyDots: View {
    let filled: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(index < filled ? PocketColor.marker : PocketColor.barDefault)
                    .frame(width: 6, height: 6)
            }
        }
        .accessibilityLabel("Proficiency \(filled) of 5")
    }
}

/// First-run / empty library: offer import or the bundled demo — ADR 0011 retires
/// the auto-seed in favour of this explicit choice.
private struct LibraryEmptyState: View {
    let onImport: () -> Void
    let onTryDemo: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 44))
                .foregroundStyle(PocketColor.textSecondary)
            Text("No songs yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PocketColor.textPrimary)
            Text("Import an audio file to practice with its real waveform.")
                .font(.footnote)
                .foregroundStyle(PocketColor.textSecondary)
                .multilineTextAlignment(.center)
            VStack(spacing: 10) {
                Button(action: onImport) {
                    Label("Import a song", systemImage: "square.and.arrow.down")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .background(PocketColor.active.opacity(0.18), in: .rect(cornerRadius: 12))
                .foregroundStyle(PocketColor.active)

                Button("Try the demo", action: onTryDemo)
                    .font(.subheadline)
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .padding(.top, 4)
        }
        .padding(40)
    }
}

#Preview("Library — with songs") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Song.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    container.mainContext.insert(Song.sample())
    return LibraryView().modelContainer(container)
}

#Preview("Library — empty") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Song.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    return LibraryView().modelContainer(container)
}

#Preview("Song edit sheet") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Song.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    let song = Song.sample()
    container.mainContext.insert(song)
    return SongEditSheet(song: song).modelContainer(container)
}
