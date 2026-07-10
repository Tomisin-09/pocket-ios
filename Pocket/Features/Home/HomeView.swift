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
    @Query private var routines: [Routine]
    @State private var importing = false
    @State private var importError: String?
    @State private var showingMetronome = false
    /// A recent routine tapped for a **replay** (exact re-run, ADR 0066) — distinct from the
    /// goal-adaptive "today's session" CTA, which regenerates. Presents the player full-screen.
    @State private var playingRoutine: Routine?

    /// How many routines the "recent routines" rail shows.
    private let recentRoutineLimit = 3

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    greeting
                    startTodaySessionCard
                    if let song = resumeSong {
                        NavigationLink {
                            WaveformPracticeView(song: song, context: context)
                        } label: {
                            JumpBackInCard(song: song)
                        }
                        .buttonStyle(.plain)
                    }
                    // The three navigation strips (songs / tool / content) read as one group,
                    // so they sit tighter together than the 28-pt rhythm separating the home's
                    // major sections.
                    VStack(spacing: 10) {
                        songLibraryCard
                        metronomeCard
                        practiceCard
                    }
                    if !recentRoutines.isEmpty { recentRoutinesRail }
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Red Moon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // The wordmark graphic (with its hidden half-note "d", ADR 0061) replaces the
                // plain title text; `navigationTitle` above still backs VoiceOver/back-button
                // labels. Light/dark artwork adapts on its own (ADR 0062).
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .principal) {
                    Image("RedMoonWordmark")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 22)
                        .accessibilityLabel("Red Moon")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    // Solid green disc with a bold dark plus — mirrors the app's
                    // dark-content-on-filled-colour convention (e.g. the plum CTA).
                    Button { importing = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(PocketColor.background)
                            .frame(width: 34, height: 34)
                            .background(Circle().fill(PocketColor.active))
                    }
                    .accessibilityLabel("Add a song")
                }
            }
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
            .fullScreenCover(item: $playingRoutine) { routine in
                RoutinePlayerView(routine: routine)
            }
            // Seed the curated Practice presets once, ever (ADR 0046). The app root is the right
            // place — they exist before the user opens Practice — and the seeder's own
            // `UserDefaults` guard makes this idempotent across launches. Routines seed **after**
            // exercises (ADR 0071) so their by-name blocks resolve against the just-seeded drills.
            // Yield between the two so the exercise library can paint before routine seeding's
            // fetch+insert+save runs — chaining both synchronously delays first render on a cold
            // install (the run-screen "freeze" that once looked like a regression was this latency).
            .task {
                PracticePresets.seedIfNeeded(into: context)
                await Task.yield()
                RoutinePresets.seedIfNeeded(into: context)
            }
        }
    }

    // MARK: - Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(HomeFeed.TimeOfDay.at(hour: Calendar.current.component(.hour, from: .now)).greeting)
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
            Text("Ready to practice?")
                .font(.futura(.largeTitle, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Start today's session (primary CTA)

    /// The **primary** home action (planner, ADR 0046/0015): a filled plum CTA that pushes
    /// `PlannerView`, where goals (set once) drive a freshly-generated, goal-adaptive session each
    /// run. Distinct from the "recent routines" rail below, which *replays* a past routine exactly.
    /// Sits in the slot the dropped "Your progress" strip vacated.
    private var startTodaySessionCard: some View {
        NavigationLink { PlannerView() } label: {
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .font(.futura(.title2))
                    .foregroundStyle(PocketColor.background)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Start today's session")
                        .font(.futura(.headline))
                        .foregroundStyle(PocketColor.background)
                    Text("A fresh session from your goals and history")
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.background.opacity(0.85))
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.futura(.footnote, weight: .semibold))
                    .foregroundStyle(PocketColor.background.opacity(0.85))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16).fill(PocketColor.practiceCTA))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start today's session")
        .accessibilityHint("A fresh session generated from your goals and practice history")
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
                    .font(.futura(.title2))
                    .foregroundStyle(PocketColor.practice)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(PocketColor.practiceCircleWash))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Practice")
                        .font(.futura(.headline))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text("Your exercises & training runs")
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.futura(.footnote, weight: .semibold))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(PocketColor.practiceCardWash))
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
                    .font(.futura(.title2))
                    .foregroundStyle(PocketColor.metronome)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(PocketColor.metronomeCircleWash))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Metronome")
                        .font(.futura(.headline))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text("Standalone click & tempo trainer")
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.futura(.footnote, weight: .semibold))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(PocketColor.metronomeCardWash))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Metronome, standalone click and tempo trainer")
    }

    // MARK: - Song library strip

    /// The songs place, folded into a single nav strip (matching the Metronome/Practice pattern) in
    /// its own **blue** identity (ADR 0023 song-surface hue, baked `library` tokens — no opacity
    /// blend, ADR 0062). Replaces the old inline "Your songs" preview list; adding a song now lives in
    /// the toolbar's green button. Together with the teal Metronome and plum Practice strips this
    /// forms the blue · teal · plum home triad (songs / tool / content).
    private var songLibraryCard: some View {
        NavigationLink { LibraryView() } label: {
            HStack(spacing: 14) {
                Image(systemName: "music.note.list")
                    .font(.futura(.title2))
                    .foregroundStyle(PocketColor.library)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(PocketColor.libraryCircleWash))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Song library")
                        .font(.futura(.headline))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text(librarySubtitle)
                        .font(.futura(.subheadline))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.futura(.footnote, weight: .semibold))
                    .foregroundStyle(PocketColor.textSecondary)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16).fill(PocketColor.libraryCardWash))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Song library, \(librarySubtitle)")
    }

    /// Count-aware subtitle: nudges an empty library toward the toolbar's add button.
    private var librarySubtitle: String {
        songs.isEmpty ? "Add a song to get started"
                      : "\(songs.count) song\(songs.count == 1 ? "" : "s")"
    }

    // MARK: - Recent routines rail

    /// The last few routines you actually **practised** (newest first), each a one-tap *exact replay*
    /// — the counterpart to the adaptive "Start today's session" CTA above. Reads `Routine.lastPracticed`
    /// (stamped on run); never-run routines don't appear.
    private var recentRoutinesRail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent routines")
                .font(.futura(.title3, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentRoutines) { routine in
                        Button { playingRoutine = routine; haptic(.light) } label: {
                            RecentRoutineCard(routine: routine)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - Derived

    /// The single most-recently-practised song — the "Jump back in" subject — or `nil` on a
    /// fresh library where nothing has been practised yet (the card hides).
    private var resumeSong: Song? {
        HomeFeed.mostRecentlyPracticed(songs, practicedAt: \.lastPracticed)
    }

    /// The recent-routines rail contents: routines actually practised, newest first, capped.
    private var recentRoutines: [Routine] {
        HomeFeed.recentlyPracticed(routines, limit: recentRoutineLimit,
                                   practicedAt: \.lastPracticed, id: \.uid)
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
    let container = try! ModelContainer(
        for: Song.self, Routine.self, RoutineItem.self, Exercise.self, Loop.self,
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
    let drill = Exercise(name: "Alternating picking", currentTempo: 70, commandTempo: 96)
    container.mainContext.insert(drill)
    for (name, offset) in [("Morning warm-up", -3600.0), ("Speed builder", -86400.0 * 3)] {
        let routine = Routine(name: name)
        routine.items = [RoutineItem.item(drill, kind: .warmup, order: 0),
                         RoutineItem.rest(order: 1),
                         RoutineItem.item(drill, order: 2)]
        routine.lastPracticed = now.addingTimeInterval(offset)
        container.mainContext.insert(routine)
    }
    try? container.mainContext.save()
    return HomeView().modelContainer(container)
}

#Preview("Home — first launch") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: Song.self, Routine.self, RoutineItem.self, Exercise.self, Loop.self,
        configurations: .init(isStoredInMemoryOnly: true))
    return HomeView().modelContainer(container)
}
