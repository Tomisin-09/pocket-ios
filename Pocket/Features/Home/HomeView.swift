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
    /// Red Moon Pro entitlement + the shared paywall (ADR 0112). Both carry safe preview defaults
    /// (free / no-op), so `HomeView` previews render without a `StoreManager` in the environment.
    @Environment(\.isPro) private var isPro
    @Environment(\.presentPaywall) private var presentPaywall
    @Query(sort: \Song.title) private var songs: [Song]
    @Query private var routines: [Routine]
    // Non-private so the `HomeView+ProfileMoment` extension (a separate file, for the length cap) can
    // read them when deciding which one-time profile moment to surface (ADR 0113).
    @Query var exercises: [Exercise]
    @Query var loops: [Loop]
    /// The local artist profile (ADR 0113). `.first?.artistName` personalises the greeting; `nil`
    /// (untouched install / no name) reads name-free.
    @Query var profiles: [Profile]
    /// One-time gate for the after-first-session name invitation, so it's offered once and never nags.
    @AppStorage(AppSettings.Key.artistNamePromptSeen) var artistNamePromptSeen = false
    /// One-time gate for the first-launch curation intake (ADR 0113 S2), so it's offered once.
    @AppStorage(AppSettings.Key.artistIntakeSeen) var artistIntakeSeen = false
    /// Drives the after-first-session artist-name sheet.
    @State var showingNamePrompt = false
    /// Drives the first-launch curation intake sheet.
    @State var showingIntake = false
    @State private var importing = false
    @State private var importError: String?
    /// Drives multi-select import: progress overlay + partial-failure summary (shared
    /// behaviour with the library's + button).
    @State private var importModel = SongImportModel()
    /// Pushes the library after a home-screen import lands songs, so the user sees
    /// where they went (from the library itself there's nowhere to go).
    @State private var showingLibrary = false
    @State private var showingMetronome = false

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
                    // The navigation strips are grouped into titled sections (ADR 0102) rather than
                    // one flat run: hierarchy keeps the home calm as destinations accrue and gives a
                    // new arrival a section to join instead of becoming a sixth same-weight peer.
                    // Interim two-section split — Toolkit rides in "Your stuff" until Red Moon Oracle
                    // ships, when Toolkit + Oracle break out into their own "Learn" section. Sections
                    // breathe at the 20-pt rhythm; strips within a section stay tight at 10.
                    VStack(alignment: .leading, spacing: 20) {
                        HomeSection(title: "Practice") {
                            practiceCard
                            metronomeCard
                        }
                        HomeSection(title: "Your stuff") {
                            songLibraryCard
                            journalCard
                            toolkitCard
                        }
                    }
                    if !recentRoutines.isEmpty { recentRoutinesRail }
                }
                .padding(20)
                // Cap the hub to a readable column so it doesn't stretch edge-to-edge at
                // regular width (iPad / iPhone Pro Max landscape). Dormant on the iPhone-only
                // v1 build — a no-op at compact width (ADR 0105).
                .readableWidth()
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
                // Drop iOS 26's shared-glass toolbar background so the green add disc
                // reads as a solid fill. The modifier is iOS-26-SDK-only, so `#if compiler`
                // gates it out of Xcode 16 CI (a runtime `#available` can't — symbol absent).
                #if compiler(>=6.2)
                if #available(iOS 26.0, *) {
                    ToolbarItem(placement: .topBarTrailing) { addSongButton }
                        .sharedBackgroundVisibility(.hidden)
                } else { ToolbarItem(placement: .topBarTrailing) { addSongButton } }
                #else
                ToolbarItem(placement: .topBarTrailing) { addSongButton }
                #endif
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.audio],
                          allowsMultipleSelection: true, onCompletion: handleImport)
            .alert("Couldn’t import", isPresented: importErrorBinding) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "")
            }
            .songImportFeedback(importModel)
            .navigationDestination(isPresented: $showingLibrary) { LibraryView() }
            .fullScreenCover(isPresented: $showingMetronome) {
                MetronomeView()
            }
            // The "you've earned a name" invitation (ADR 0113). Offered once, full-screen, only
            // after the player has completed an exercise or captured a loop, and only if they
            // haven't named themselves yet; dismissing (This is me or Not now) marks it seen so it
            // never returns. The name stays editable in Settings regardless.
            .fullScreenCover(isPresented: $showingNamePrompt,
                             onDismiss: { artistNamePromptSeen = true },
                             content: { ArtistNamePromptSheet(profile: profiles.first) })
            // The first-launch curation intake (ADR 0113 S2). Offered once, before any name is
            // earned; dismissing (Done or Skip) marks it seen so it never returns. The fields stay
            // editable in Settings. Mutually exclusive with the name prompt (see maybeOfferProfileMoment).
            .fullScreenCover(isPresented: $showingIntake,
                             onDismiss: { artistIntakeSeen = true },
                             content: { ArtistIntakeView() })
            .onAppear(perform: maybeOfferProfileMoment)
            // Seed the curated Practice presets once, ever (ADR 0046). The app root is the right
            // place — they exist before the user opens Practice — and the seeder's own
            // `UserDefaults` guard makes this idempotent across launches. Routines seed **after**
            // exercises (ADR 0071) so their by-name blocks resolve against the just-seeded drills.
            // Yield between the two so the exercise library can paint before routine seeding's
            // fetch+insert+save runs — chaining both synchronously delays first render on a cold
            // install (the run-screen "freeze" that once looked like a regression was this latency).
            .task {
                PracticePresets.seedIfNeeded(into: context)
                // Stamp preset provenance onto drills seeded before the slug field existed (ADR 0112),
                // so the paywall's free-taste run allowance recognises them. Guarded to run once.
                PracticePresets.backfillPresetSlugsIfNeeded(into: context)
                await Task.yield()
                RoutinePresets.seedIfNeeded(into: context)
                #if DEBUG
                ScreenshotSeed.seedIfNeeded(into: context)
                #endif
            }
        }
    }

    // MARK: - Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(HomeFeed.TimeOfDay.at(hour: Calendar.current.component(.hour, from: .now))
                .greeting(name: profiles.first?.artistName))
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
            Text("Ready to practice?")
                .font(.futura(.largeTitle, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Start today's session (primary CTA)

    // MARK: - Practice card

    /// The top-level **Practice** space (ADR 0046) — where trainable units live and
    /// command-anchored runs happen. A push (it's a *place* with its own list and run screens),
    /// in the brand teal accent (`PocketColor.practice`, the brand hero) so it reads as distinct
    /// from the metronome tool below it.
    private var practiceCard: some View {
        NavigationLink { PracticeView() } label: {
            HomeNavCard(icon: "figure.run", title: "Practice",
                        subtitle: "Your exercises & training runs",
                        tint: PocketColor.practice,
                        cardWash: PocketColor.practiceCardWash,
                        circleWash: PocketColor.practiceCircleWash)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Practice, your exercises and training runs")
    }

    // MARK: - Toolkit card

    /// The **Toolkit** hub (ADR 0096) — the free, deterministic reference destination (My Chords +
    /// Glossary in Slice 1). A push (it's a *place* with its own list of sections), in the new
    /// indigo/violet "study/reference" accent (`PocketColor.toolkit`), the fourth home hue kept clear
    /// of the teal · plum · terracotta triad above it.
    private var toolkitCard: some View {
        NavigationLink { ToolkitView() } label: {
            HomeNavCard(icon: "books.vertical.fill", title: "Toolkit",
                        subtitle: "Your chords & a music glossary",
                        tint: PocketColor.toolkit,
                        cardWash: PocketColor.toolkitCardWash,
                        circleWash: PocketColor.toolkitCircleWash)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Toolkit, your chords and a music glossary")
    }

    // MARK: - Journal card

    /// The **Journal** space (ADR 0100) — the read-only practice-history destination that aggregates
    /// notes + takes across loops and exercises. The 4th strip (between Practice and Toolkit), in its
    /// own warm **gold** identity (`PocketColor.journal`), a fifth home hue kept clear of the
    /// teal · plum · terracotta triad and the indigo reference hub.
    private var journalCard: some View {
        NavigationLink { JournalTabView() } label: {
            HomeNavCard(icon: "book.closed.fill", title: "Journal",
                        subtitle: "Your notes & practice takes",
                        tint: PocketColor.journal,
                        cardWash: PocketColor.journalCardWash,
                        circleWash: PocketColor.journalCircleWash)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Journal, your notes and practice takes")
    }

    // MARK: - Metronome card

    /// The standalone metronome (plum, `PocketColor.metronome` — the one theme-invariant home
    /// hue), presented full-screen (it owns its own navigation + dismiss, ADR 0043).
    private var metronomeCard: some View {
        Button { showingMetronome = true } label: {
            HomeNavCard(icon: "metronome.fill", title: "Metronome",
                        subtitle: "Standalone click & tempo trainer",
                        tint: PocketColor.metronome,
                        cardWash: PocketColor.metronomeCardWash,
                        circleWash: PocketColor.metronomeCircleWash)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Metronome, standalone click and tempo trainer")
    }

    // MARK: - Song library strip

    /// The songs place, folded into a single nav strip (matching the Metronome/Practice pattern) in
    /// its own warm **terracotta** identity (baked `library` tokens — no opacity blend, ADR
    /// 0062/0081). Replaces the old inline "Your songs" preview list; adding a song now lives in the
    /// toolbar's green button. Together with the teal Practice and plum Metronome strips this forms
    /// the teal · plum · terracotta home triad (content / tool / songs).
    private var songLibraryCard: some View {
        NavigationLink { LibraryView() } label: {
            HomeNavCard(icon: "music.note.list", title: "Song library",
                        subtitle: librarySubtitle,
                        tint: PocketColor.library,
                        cardWash: PocketColor.libraryCardWash,
                        circleWash: PocketColor.libraryCircleWash)
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

    /// The last few routines you actually **practised** (newest first). A tap **reopens the routine's
    /// detail** (`RoutineDetailView` — blocks + Edit + Start), rather than replaying it straight into
    /// the player, so you can glance at the blocks or tweak before starting (device feedback
    /// 2026-07-11; supersedes ADR 0066's one-tap replay *from home* — the library ▶ still replays
    /// directly). Reads `Routine.lastPracticed` (stamped on run); never-run routines don't appear.
    private var recentRoutinesRail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Recent routines")
                .font(.futura(.title3, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(recentRoutines) { routine in
                        NavigationLink {
                            RoutineDetailView(container: context.container, existing: routine)
                        } label: {
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

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                let outcome = await importModel.run(urls: urls, into: context)
                // Land the user in the library so they see the songs they just added;
                // if nothing imported (all skipped), stay put — the summary alert explains.
                if outcome.imported > 0 { showingLibrary = true }
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }
}

/// The add-song toolbar button, split into an extension so `HomeView`'s body stays within
/// SwiftLint's `type_body_length`.
private extension HomeView {
    /// Solid green disc with a bold dark plus — mirrors the app's dark-content-on-filled-colour
    /// convention (e.g. the teal CTA). Its enclosing `ToolbarItem` drops the iOS 26 shared glass
    /// background so the disc reads as a flat fill.
    var addSongButton: some View {
        Button { importing = true } label: {
            Image(systemName: "plus")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(PocketColor.background)
                .frame(width: 34, height: 34)
                .background(Circle().fill(PocketColor.active))
        }
        .accessibilityLabel("Add a song")
    }

    /// The **primary** home action (planner, ADR 0046/0015): a filled teal CTA that pushes
    /// `PlannerView`, where goals (set once) drive a freshly-generated, goal-adaptive session each
    /// run. Today's session is a **Pro** feature (ADR 0112): Pro pushes the planner; a free player
    /// gets the paywall instead, with a small lock so the card reads as inviting-but-locked, not
    /// broken. In its own extension so `HomeView`'s body stays within `type_body_length`.
    var startTodaySessionCard: some View {
        Group {
            if isPro {
                NavigationLink { PlannerView() } label: { startTodaySessionLabel }
            } else {
                Button { presentPaywall(.planner) } label: { startTodaySessionLabel }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Start today's session")
        .accessibilityHint("A fresh session generated from your goals and practice history")
    }

    var startTodaySessionLabel: some View {
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
            // Free players see a lock (a Pro gate); Pro sees the usual chevron.
            Image(systemName: isPro ? "chevron.right" : "lock.fill")
                .font(.futura(.footnote, weight: .semibold))
                .foregroundStyle(PocketColor.background.opacity(0.85))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(PocketColor.practiceCTA))
    }
}
