import SwiftData
import SwiftUI

/// The app's **front door** (ADR 0044), and since ADR 0197 a screen with a shape: what changed
/// since yesterday on top, the map underneath.
///
/// Top to bottom — a time-of-day greeting, the trial countdown while one is running, the
/// `Start today's session` CTA, the `Jump back in` card for whichever unit the player pinned
/// (ADR 0193), the `This week` strip (ADR 0196), the six destinations as a tile grid
/// (`HomeView+Map`), and the recent-routines rail. It is the app root in place of `LibraryView`
/// and retires the temporary metronome toolbar button (ADR 0043).
///
/// **The ordering is the argument.** Everything above the map is different from yesterday and
/// everything in it is not: the six destinations have been the same six since the Oracle landed
/// and will not change again this year. Six full-width strips put that unchanging half in the
/// player's way every launch — ADR 0197 is what shrank it back to an index.
struct HomeView: View {
    /// Internal, not private: `HomeView+Seeding` writes the first-run content through it.
    @Environment(\.modelContext) var context
    /// Red Moon Pro entitlement + the shared paywall (ADR 0112). Both carry safe preview defaults
    /// (free / no-op), so `HomeView` previews render without a `StoreManager` in the environment.
    /// Non-private (like the `@Query`s below) so the `HomeView+Actions` extension can gate its CTA.
    @Environment(\.isPro) var isPro
    @Environment(\.presentPaywall) var presentPaywall
    /// Practice reminders (ADR 0186). Home owns the launch sweep (D3) and the tap landing (D6),
    /// because both need a `ModelContext` to resolve a `uid` against and this is where the store is.
    @Environment(PracticeReminder.self) var practiceReminder
    /// The mailbox `AppDelegate` posts a tapped reminder's routine into (ADR 0186 D6). A shared
    /// instance rather than an environment value because the delegate that fills it lives outside
    /// the SwiftUI environment entirely; `@Observable` still tracks it from here.
    let notificationRouter = NotificationRouter.shared
    /// Non-private since ADR 0193: `HomeView+Resume` reads them to pick the card's subject.
    @Query(sort: \Song.title) var songs: [Song]
    @Query var routines: [Routine]
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
    /// Which kind the "Jump back in" card offers (ADR 0193). Stored raw and resolved through
    /// `AppSettings`, so an unrecognised value degrades to the default instead of trapping — and
    /// bound to `AppSettings.jumpBackInPreferenceDefault`, never a literal, because the value an
    /// `@AppStorage` declares is what SwiftUI uses for an unset key and it does not consult the
    /// accessor. The hold menu writes this binding directly.
    @AppStorage(AppSettings.Key.jumpBackIn)
    var jumpBackInRaw = AppSettings.jumpBackInPreferenceDefault.rawValue
    /// One-time gate for the analytics sheet, so it appears once and never nags. Covers being
    /// *told* as well as being *asked* (ADR 0147) — the key string is unchanged so no install
    /// re-sees it.
    @AppStorage(AppSettings.Key.analyticsPromptSeen) var analyticsDisclosureSeen = false
    /// Drives the after-first-practice analytics consent cover.
    @State var showingAnalyticsConsent = false
    /// Drives the after-first-session artist-name sheet.
    @State var showingNamePrompt = false
    /// Drives the first-launch curation intake sheet.
    @State var showingIntake = false
    /// Drives the file importer — non-private for the add-song button in `HomeView+Actions`.
    @State var importing = false
    @State private var importError: String?
    /// Drives multi-select import: progress overlay + partial-failure summary (shared
    /// behaviour with the library's + button).
    @State private var importModel = SongImportModel()
    /// Pushes the library after a home-screen import lands songs, so the user sees
    /// where they went (from the library itself there's nowhere to go).
    @State private var showingLibrary = false
    /// The song a single-file import just created — pushed straight to its waveform instead of the
    /// library ("open on create"). A batch still lands in the library.
    @State private var openingSong: Song?
    /// The routine a tapped reminder asked for (ADR 0186 D6), resolved out of the store; `nil` when
    /// none. Bool-bound below for the same reason `openingSong` is — see that destination.
    @State var openingRoutine: Routine?
    /// Drives the full-screen metronome — non-private since ADR 0197, because the tile that sets
    /// it lives in `HomeView+Map`.
    @State var showingMetronome = false
    /// Set when `seedFirstRunContent()` finishes, purely so `seedingMarker` can publish it to the UI
    /// tests (ADR 0146 pass 2). Nothing the player sees depends on it — seeded content appears
    /// through `@Query` as each seeder commits, exactly as before. Internal, not private, because
    /// both live in `HomeView+Seeding`.
    @State var seedingComplete = false

    /// How many routines the "recent routines" rail shows.
    private let recentRoutineLimit = 3

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    greeting
                    // Present only while a free trial is running (ADR 0144 D6) — draws nothing
                    // otherwise, so it costs the ordinary Home nothing.
                    TrialCountdownRow()
                    startTodaySessionCard
                    // Which unit this offers is the player's choice since ADR 0193; the card, its
                    // Pro gate and the hold that changes the choice live in `HomeView+Resume`.
                    if let target = resumeTarget { resumeCard(target) }
                    // The one thing on Home that changed since yesterday (ADR 0196). Below the
                    // resume card, because what you were doing outranks how much of it there has
                    // been; above the navigation sections, because those are static for the life of
                    // the app. Draws nothing at all until something has been practised, so a fresh
                    // install is unchanged.
                    HomeStatsStrip()
                    // The six destinations, grouped into the titled sections ADR 0102 fixed and
                    // drawn as a 2-up tile grid since ADR 0197 — hierarchy keeps the home calm as
                    // destinations accrue, and the tiles are what stop the map from owning the
                    // screen it is only the index to. It lives whole in `HomeView+Map`.
                    homeMap
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
            // Import a single song from the hub and it opens for practice. Bool-bound, not
            // `item:`-bound: a just-inserted `Song`'s `persistentModelID` flips on the first autosave
            // and would pop an item-based destination (ADR 0090; `docs/swiftdata-gotchas.md`).
            .navigationDestination(isPresented: Binding(get: { openingSong != nil },
                                                        set: { if !$0 { openingSong = nil } })) {
                if let song = openingSong {
                    WaveformPracticeView(song: song, context: context)
                }
            }
            // Where a tapped reminder lands (ADR 0186 D6) — see `HomeView+Routines`.
            .navigationDestination(isPresented: Binding(get: { openingRoutine != nil },
                                                        set: { if !$0 { openingRoutine = nil } })) {
                openedRoutineDestination
            }
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
            // The analytics sheet — a consent ask under `.ask`, a catch-up notice under `.notify`
            // (ADR 0120, region-split by ADR 0147). Shown once, last on the ladder so it never
            // competes with a profile moment. Marking it seen on dismiss — rather than on answer —
            // means every exit closes it, including any dismissal path added later.
            .fullScreenCover(isPresented: $showingAnalyticsConsent,
                             onDismiss: { analyticsDisclosureSeen = true },
                             content: {
                                 AnalyticsConsentSheet(
                                     mode: AnalyticsPolicy.consentModel(
                                         regionCode: Locale.current.region?.identifier))
                             })
            .onAppear(perform: maybeOfferProfileMoment)
            // Seeding first, then the reminder sweep — the ordering is load-bearing, see
            // `sweepOrphanedReminders`.
            .task { await seedFirstRunContent(); await sweepOrphanedReminders() }
            .onChange(of: notificationRouter.pendingRoutineUID) { _, _ in openRoutineFromReminder() }
            .onAppear(perform: openRoutineFromReminder)
            .overlay(alignment: .topLeading) { seedingMarker }
        }
    }

    // MARK: - Greeting

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 2) {
            // `shotHour` is nil in every normal launch; the manual's shoot names an hour so the
            // greeting agrees with the status bar it fakes (see `UITestHooks.shotHourArgument`).
            Text(HomeFeed.TimeOfDay
                .at(hour: UITestRuntime.shotHour
                    ?? Calendar.current.component(.hour, from: .now))
                .greeting(name: profiles.first?.artistName))
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
            Text("Ready to practice?")
                .font(.futura(.largeTitle, weight: .semibold))
                .foregroundStyle(PocketColor.textPrimary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Song library subtitle

    /// Count-aware library copy: it nudges an empty library toward the toolbar's add button, and
    /// carries the count otherwise. Since ADR 0197 it is the **accessibility label's** tail on every
    /// install and the Song library tile's visible caption on an empty one — one string either way,
    /// so a fresh install's nudge and what VoiceOver reads cannot drift apart. Non-private because
    /// the tile that reads it lives in `HomeView+Map`.
    var librarySubtitle: String {
        songs.isEmpty ? "Add a song to get started"
                      : "\(songs.count) song\(songs.count == 1 ? "" : "s")"
    }

    // MARK: - Derived

    /// The recent-routines rail contents: routines actually practised, newest first, capped.
    var recentRoutines: [Routine] {
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
                // One song: open it — importing a single file is the start of practising it.
                if let song = importModel.takeSongToOpen(after: outcome) {
                    openingSong = song
                    return
                }
                // Otherwise land the user in the library so they see the songs they just added;
                // if nothing imported (all skipped), stay put — the summary alert explains.
                if outcome.imported > 0 { showingLibrary = true }
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }
}
