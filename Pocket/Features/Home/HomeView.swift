import SwiftData
import SwiftUI

/// The app's **front door** (V1 home hub, ADR 0044 follow-on): a time-of-day greeting, a
/// "Jump back in" card for the song you last practised, the standalone metronome, a short
/// preview of your songs (full library one tap away), and a way to add one. Becomes the app
/// root in place of `LibraryView` and retires the temporary metronome toolbar button (ADR
/// 0043). The planner that the design brief once pencilled in here is V2 — this is a
/// deliberately planner-free V1 home.
struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Song.title) private var songs: [Song]
    @State private var importing = false
    @State private var importError: String?
    @State private var showingMetronome = false

    /// How many songs the "Your songs" preview lists before deferring to "See all".
    private let previewLimit = 4

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    greeting
                    if let song = resumeSong {
                        NavigationLink {
                            WaveformPracticeView(song: song, context: context)
                        } label: {
                            JumpBackInCard(song: song)
                        }
                        .buttonStyle(.plain)
                    }
                    practiceCard
                    metronomeCard
                    if !songs.isEmpty { yourSongs }
                    addSongButton
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Pocket")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(isPresented: $importing, allowedContentTypes: [.audio],
                          onCompletion: handleImport)
            .alert("Couldn’t import", isPresented: importErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
            .fullScreenCover(isPresented: $showingMetronome) {
                MetronomeView()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(HomeFeed.TimeOfDay.at(hour: Calendar.current.component(.hour, from: .now)).greeting)
                .font(.subheadline)
                .foregroundStyle(PocketColor.textSecondary)
            Text("Ready to practice")
                .font(.largeTitle.weight(.semibold))
                .foregroundStyle(PocketColor.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Practice card

    /// The top-level **Practice** space (ADR 0046) — where trainable units live and
    /// command-anchored runs happen. A push (it's a *place* with its own list and run screens),
    /// in its own indigo accent (`PocketColor.practice`) so it reads as distinct from the
    /// metronome tool below it.
    private var practiceCard: some View {
        NavigationLink { PracticeView() } label: {
            HStack(spacing: 14) {
                Image(systemName: "figure.run")
                    .font(.title2)
                    .foregroundStyle(PocketColor.practice)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(PocketColor.practice.opacity(0.15)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Practice")
                        .font(.headline)
                        .foregroundStyle(PocketColor.textPrimary)
                    Text("Your exercises & training runs")
                        .font(.subheadline)
                        .foregroundStyle(PocketColor.textSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(PocketColor.practice.opacity(0.10)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Practice, your exercises and training runs")
    }

    // MARK: - Metronome card

    /// The one splash of colour on the screen (teal, `PocketColor.metronome`) — the standalone
    /// metronome, presented full-screen (it owns its own navigation + dismiss, ADR 0043).
    private var metronomeCard: some View {
        Button { showingMetronome = true } label: {
            HStack(spacing: 14) {
                Image(systemName: "metronome.fill")
                    .font(.title2)
                    .foregroundStyle(PocketColor.metronome)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(PocketColor.metronome.opacity(0.15)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Metronome")
                        .font(.headline)
                        .foregroundStyle(PocketColor.textPrimary)
                    Text("Standalone click & tempo trainer")
                        .font(.subheadline)
                        .foregroundStyle(PocketColor.textSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(PocketColor.metronome.opacity(0.10)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Metronome, standalone click and tempo trainer")
    }

    // MARK: - Your songs

    private var yourSongs: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Your songs")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PocketColor.textPrimary)
                Spacer()
                NavigationLink { LibraryView() } label: {
                    Text("See all")
                        .font(.subheadline)
                        .foregroundStyle(PocketColor.active)
                }
            }
            VStack(spacing: 0) {
                ForEach(Array(previewSongs.enumerated()), id: \.element.persistentModelID) { index, song in
                    if index > 0 { Divider().overlay(PocketColor.barPlayed) }
                    NavigationLink {
                        WaveformPracticeView(song: song, context: context)
                    } label: {
                        SongCard(song: song)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Add a song

    private var addSongButton: some View {
        Button { importing = true } label: {
            Label("Add a song", systemImage: "plus.circle.fill")
                .font(.headline)
                .foregroundStyle(PocketColor.active)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(RoundedRectangle(cornerRadius: 14).fill(PocketColor.active.opacity(0.14)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add a song")
    }

    // MARK: - Derived

    /// The single most-recently-practised song — the "Jump back in" subject — or `nil` on a
    /// fresh library where nothing has been practised yet (the card hides).
    private var resumeSong: Song? {
        HomeFeed.mostRecentlyPracticed(songs, practicedAt: \.lastPracticed)
    }

    /// The "Your songs" preview: every song ordered by recent practice, with the resume song
    /// dropped (it already headlines the card above), capped at `previewLimit`.
    private var previewSongs: [Song] {
        let resumeID = resumeSong?.persistentModelID
        let ordered = HomeFeed.orderedForHome(songs, practicedAt: \.lastPracticed, title: \.title)
        return Array(ordered.filter { $0.persistentModelID != resumeID }.prefix(previewLimit))
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
}

/// The "Jump back in" card: the song you last practised, with its mastery and when you last
/// touched it. Resumes the song (at its last-practiced tempo, ADR 0044) on tap. Neutral
/// chrome — the metronome card owns the screen's one accent colour.
private struct JumpBackInCard: View {
    let song: Song

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("JUMP BACK IN")
                .font(.caption2.weight(.semibold))
                .tracking(1.5)
                .foregroundStyle(PocketColor.textSecondary)
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(PocketColor.textPrimary)
                        .lineLimit(1)
                    if !song.artist.isEmpty {
                        Text(song.artist)
                            .font(.subheadline)
                            .foregroundStyle(PocketColor.textSecondary)
                            .lineLimit(1)
                    }
                    if let practiced = song.lastPracticed {
                        Text("Last practised \(Self.relative(practiced))")
                            .font(.footnote)
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                }
                Spacer(minLength: 8)
                MasteryReadout(mastery: song.mastery)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06)))
    }

    /// "2 days ago" — a relative, human description of the last practice time.
    private static func relative(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

/// A varied home preview seed: a song with a derived mastery and a relative last-practice time
/// (`nil` ⇒ never practised, so it lands after the practised ones and out of the resume card).
private struct HomePreviewSeed {
    let title: String
    let artist: String
    let mastery: Int?
    let practicedOffset: TimeInterval?

    static let library: [HomePreviewSeed] = [
        .init(title: "Little Wing", artist: "Jimi Hendrix", mastery: 2, practicedOffset: -3600 * 5),
        .init(title: "Blue Hour", artist: "The Allmans", mastery: 4, practicedOffset: -86400 * 2),
        .init(title: "Apex", artist: "Arc", mastery: 5, practicedOffset: -86400 * 9),
        .init(title: "Red Moon", artist: "Zydeco Trio", mastery: 1, practicedOffset: nil),
        .init(title: "3 Strikes", artist: "", mastery: nil, practicedOffset: nil)
    ]
}

#Preview("Home — with history") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Song.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    let now = Date()
    for seed in HomePreviewSeed.library {
        let song = Song.sample()
        song.title = seed.title
        song.artist = seed.artist
        if let mastery = seed.mastery { song.loops.forEach { $0.mastery = mastery } } else { song.loops = [] }
        song.lastPracticed = seed.practicedOffset.map { now.addingTimeInterval($0) }
        container.mainContext.insert(song)
    }
    return HomeView().modelContainer(container)
}

#Preview("Home — first launch") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Song.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    return HomeView().modelContainer(container)
}
