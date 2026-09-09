import SwiftData
import SwiftUI

/// The **Exercises** library inside Practice (ADR 0046): the focused list of click-only,
/// command-anchored drills — your own plus the seeded starters — pushed from the Practice hub.
/// Owns exercise **creation** (the `+` → `NewExerciseSheet`) and **deletion**, since exercises live
/// here and nowhere else. Tapping one opens its `ExerciseRunView`; holding one opens the shared row
/// menu (Details · Duplicate · Favourite · Delete) via `.pocketRowActions` — the same affordances,
/// in the same order, as every other list in the app (Slice 3). Delete is deferred behind an Undo
/// toast, so the list filters out rows the `rowDeletion` seam reports as pending.
///
/// Relies on an ambient `NavigationStack` (Practice → Home's stack), like the hub. Sort key +
/// direction and the search query narrow the list in memory (ADR 0056) via the pure
/// `PracticeLibrarySort`, so `@Query` stays unsorted and deletion indexes the *displayed* list.
struct ExerciseLibraryView: View {
    // Internal, not private, so `ExerciseLibraryView+Folders` can reach it — a same-module
    // extension in another file cannot see `private` (the `+Row` precedent).
    @Environment(\.modelContext) var context
    /// Red Moon Pro entitlement + the shared paywall (ADR 0112); safe preview defaults (free / no-op).
    @Environment(\.isPro) private var isPro
    @Environment(\.presentPaywall) private var presentPaywall
    /// Deferred, undoable row deletion (Slice 3). **Owned here, not by the modifier**: this view
    /// reads `isPending` itself to filter out a row awaiting its delete, and a modifier applied
    /// inside `body` can only publish to its descendants.
    @State private var rowDeletion = RowDeletionCoordinator()
    @Query var exercises: [Exercise]
    /// The local profile (ADR 0113 S2): its self-rated experience seeds a new exercise's default
    /// command tempo, so a beginner starts near the floor and a seasoned player higher up.
    @Query private var profiles: [Profile]
    @State private var creating = false
    /// The exercise just created by the sheet, staged for its run screen. Two states rather than one
    /// because the push has to wait for the sheet to leave: `justCreated` is written by `create` while
    /// the sheet is still up, then promoted to `opening` in `onDismiss` — presenting into a dismissing
    /// sheet drops the push.
    @State private var justCreated: Exercise?
    @State private var opening: Exercise?
    /// The drill whose read-only reference sheet is open (Slice 3's "view info" row action) — the
    /// same `ExerciseDetailSheet` the run screen's ⓘ opens, now reachable without starting a run.
    @State private var detailExercise: Exercise?
    /// A song tapped in that sheet's **Songs** section, on its way to the player (ADR 0172) — the
    /// same two-state hand-off as `justCreated` → `opening` above, for the same reason, and shared
    /// with the run screen's ⓘ, which offers the identical route (`LinkedSongRoute`).
    @State private var songRoute = LinkedSongRoute()
    /// Sort key + direction, persisted across launches (ADR 0056).
    @AppStorage("exerciseLibrarySort") private var sortKey: ExerciseSortKey = .name
    @AppStorage("exerciseLibrarySortAscending") private var sortAscending = true
    @State var searchText = ""
    /// Which template sections are collapsed, persisted across launches (Slice 5). Collapsed is what's
    /// stored, so a template you first use tomorrow arrives open.
    @AppStorage("exerciseLibraryCollapsedSections") private var collapsedSections = ""
    /// Whether the list is narrowed to favourited drills (ADR 0119) — a session toggle, not persisted.
    @State private var favoritesOnly = false
    /// The active instrument filter (ADR 0116 S4), `nil` = "All". Purely a session filter — not
    /// persisted, since it's only reachable once the library holds more than one instrument, and it
    /// resets whenever that stops being true (`showsInstrumentFilter`).
    @State private var instrumentFilter: Instrument?
    /// Whether the file picker for a shared drill is up (ADR 0209 D4). The picking is all this screen
    /// does — the file goes to the app-wide door, which reads it and decides what it holds.
    @State var importingExercise = false
    /// The app's one receiving door (ADR 0188 S2, ADR 0209 D4), shared with the Routines library.
    @Environment(\.receivePracticeFile) var receivePracticeFile
    /// Where in the folder tree this library is standing, and the three prompts that change it
    /// (ADR 0210). Session state, not persisted: a folder is a place you stand, and a library that
    /// reopened three levels down would look empty for reasons the player could not see.
    @State var folderBrowse = FolderBrowseState()
    /// The empty-folder markers (ADR 0210 D4). Queried rather than fetched so creating a folder
    /// redraws the list.
    @Query var folderMarkers: [PracticeFolder]
    /// The routines — read **only** for their folder paths. Folders are one namespace across two
    /// libraries (D3), so a folder holding nothing but routines still has to appear here; without
    /// this the Exercises library would quietly show a different tree from the Routines one.
    @Query var routines: [Routine]
    /// The drill whose folder picker is open (D9), or `nil`.
    @State var filing: Exercise?
    /// Whether the **Folders** section is open, persisted across launches and **default off**.
    ///
    /// The opposite default to the template sections, deliberately (ADR 0210 D6). Folders are not
    /// new content; they are a second axis over a screen that already worked, and D6b's claim is
    /// that the root stays the library you already had. Expanded it did not: the tag backfill gives
    /// a seeded library ten one-drill folders, which filled the display and pushed every drill below
    /// the fold — four UI tests stopped finding a seeded drill, which is that defect as a failure.
    @AppStorage("exerciseLibraryFoldersExpanded") var foldersExpanded = false

    /// The drills actually on screen — everything except rows whose delete is pending behind the
    /// Undo toast (Slice 3). The empty state reads from here too, so deleting your last drill says
    /// "no exercises yet" rather than "nothing matches your search".
    var presentExercises: [Exercise] {
        exercises.filter { !rowDeletion.isPending($0.uid) }
    }

    /// The exercises narrowed by search **and** the active instrument filter, then grouped into
    /// **template sections** (ADR 0068), each ordered by the current sort — the sectioned list the
    /// user sees, and what deletion indexes into (per section).
    private var sections: [LibrarySection<Exercise>] {
        let matched = scopedExercises.filter {
            (!favoritesOnly || $0.isFavorite)
                && PracticeLibrarySort.exerciseMatches(fields(for: $0), query: searchText,
                                                       instrument: activeInstrumentFilter)
        }
        return PracticeLibrarySort.exerciseSections(matched, sortedBy: sortKey,
                                                    ascending: sortAscending, fields: fields(for:))
    }

    /// Whether any exercise matches the current search — drives the empty vs no-match states.
    private var hasMatches: Bool { sections.contains { !$0.items.isEmpty } }

    /// The distinct instruments present in the library, canonical order (ADR 0116 S4).
    private var presentInstruments: [Instrument] {
        PracticeLibrarySort.instrumentsPresent(presentExercises.map(\.instrument))
    }

    /// Progressive disclosure: the instrument filter surfaces only once the library holds more than
    /// one instrument's content, so the single-instrument player never sees it (ADR 0116 S4).
    private var showsInstrumentFilter: Bool { presentInstruments.count > 1 }

    /// The instrument filter actually applied to the list — `nil` (All) whenever the control is
    /// hidden, so a stale selection can never silently narrow the list once disclosure retracts.
    private var activeInstrumentFilter: Instrument? { showsInstrumentFilter ? instrumentFilter : nil }

    /// One section's rows. Lifted out of `body` because inlining it put the row modifiers, the
    /// section header's arguments and the list builder in one expression the type-checker gave up on.
    @ViewBuilder private func rows(of section: LibrarySection<Exercise>) -> some View {
        ForEach(section.items) { exercise in
            exerciseRow(exercise)
                .listRowBackground(PocketColor.background)
                .pocketRowActions(displayName(exercise),
                                  tint: PocketColor.practice,
                                  menu: menuItems(for: exercise),
                                  favorite: favorite(for: exercise),
                                  delete: deletion(for: exercise))
        }
    }

    private func fields(for exercise: Exercise) -> ExerciseSortFields {
        ExerciseSortFields(name: exercise.name, command: exercise.command,
                           dateAdded: exercise.dateAdded,
                           notesPerBeat: exercise.noteRate?.perBeat ?? 1,
                           templateName: exercise.template.displayName,
                           templateIcon: exercise.template.iconName,
                           instrument: exercise.instrument)
    }

    var body: some View {
        List {
            if presentExercises.isEmpty {
                Text("No exercises yet. Tap + to create one — a named drill you push faster "
                     + "over time.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else if !hasMatches {
                folderRows
                Text(noMatchMessage)
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
                searchAllFoldersButton
            } else {
                folderRows
                ForEach(sections, id: \.title) { section in
                    CollapsibleLibrarySection(title: section.title,
                                              count: section.items.count,
                                              isExpanded: expansion(of: section.title),
                                              icon: section.icon) {
                        rows(of: section)
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        // Deferred delete + the Undo toast for every row on this screen (Slice 3).
        .pocketRowUndoHost(rowDeletion)
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                if !folderBrowse.path.isEmpty {
                    FolderBrowseBar(crumbs: folderBrowse.crumbs(root: "Exercises")) {
                        folderBrowse.open($0)
                    }
                }
                if showsInstrumentFilter {
                    InstrumentFilterBar(instruments: presentInstruments, selection: $instrumentFilter)
                }
            }
        }
        .onChange(of: showsInstrumentFilter) { _, shows in
            // Once the library drops back to a single instrument, forget any selection so it can't
            // re-narrow the list if a second instrument is added again later.
            if !shows { instrumentFilter = nil }
        }
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Exercises")
        // Leading is the back button alone; sort + favourites collapse into one fixed-width
        // trailing control so the inline title sits centred and stops moving with the sort key.
        // See `LibraryOptionsMenu`.
        .toolbar {
            // The menu itself is **unconditional**, and only the favourites filter takes the
            // emptiness — the shape `RoutineLibraryView` already uses, adopted here when the receive
            // row arrived (ADR 0209). Hiding the whole menu on an empty library would hide
            // *Receive an exercise…* at precisely the moment a player most wants it: a first drill
            // arriving from somebody else, with nothing of their own to show yet.
            ToolbarItem(placement: .topBarTrailing) {
                LibraryOptionsMenu(favoritesOnly: $favoritesOnly,
                                   showsFavoritesFilter: !presentExercises.isEmpty,
                                   actions: {
                    newFolderButton
                    receiveExerciseButton
                }, sortControls: {
                    LibrarySortPickers(sortKey: $sortKey, ascending: $sortAscending)
                })
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true; haptic(.light) } label: {
                    Image(systemName: "plus")
                }
                .tint(PocketColor.practice)
                .accessibilityLabel("New exercise")
            }
        }
        // The same picker the Routines library uses, handing off to the same door (ADR 0209 D4).
        .practiceFileImporter(isPresented: $importingExercise, onPick: receivePracticeFile)
        .sheet(isPresented: $creating, onDismiss: openJustCreated) {
            NewExerciseSheet(initialCommand: defaultCommand, defaultInstrument: defaultInstrument,
                             onCreate: create)
        }
        // Open on create: a drill you just authored pushes straight to its run screen, so creating and
        // playing are one move instead of "create, find it in the list, tap it". Presented by a Bool
        // rather than `.navigationDestination(item:)` — a just-inserted model's `persistentModelID`
        // flips temporary→permanent on the first autosave, and item-based presentation reads that as
        // an identity change and pops the screen (ADR 0090; `docs/swiftdata-gotchas.md`).
        .navigationDestination(isPresented: Binding(get: { opening != nil },
                                                    set: { if !$0 { opening = nil } })) {
            if let exercise = opening { ExerciseRunScreen(exercise: exercise) }
        }
        // Details, from the row's long-press menu. Bool-bound rather than `.sheet(item:)` for the
        // ADR 0090 reason the whole app now follows: a model's `persistentModelID` can flip on a
        // save mid-edit and dismiss an item-based sheet.
        .sheet(isPresented: Binding(get: { detailExercise != nil },
                                    set: { if !$0 { detailExercise = nil } }),
               onDismiss: { songRoute.promote() },
               content: {
            if let exercise = detailExercise {
                // Tapping a linked song stages it and closes the sheet; `onDismiss` does the push.
                // The player can't run inside the sheet — it rotates (ADR 0042) and holds a
                // keep-awake lease, and neither survives a modal.
                ExerciseDetailSheet(exercise: exercise, onOpenSong: { song in
                    songRoute.stage(song)
                    detailExercise = nil
                })
            }
        })
        .linkedSongPlayer($songRoute)
        // The three folder prompts (New folder, Rename, Delete), shared with the Routines library.
        .folderBrowsing(folderBrowse)
        .sheet(isPresented: Binding(get: { filing != nil },
                                    set: { if !$0 { filing = nil } })) {
            folderPicker
        }
    }

    private func displayName(_ exercise: Exercise) -> String {
        exercise.name.isEmpty ? "Untitled" : exercise.name
    }

    /// Whether a template section shows its drills, and the write-back that persists a tap. A live
    /// search forces every section open, so a query can never match a drill inside a collapsed
    /// bucket and look like it found nothing.
    private func expansion(of title: String) -> Binding<Bool> {
        Binding(get: {
            LibrarySectionExpansion.isExpanded(title, in: collapsedSections,
                                               searching: !searchText.isEmpty)
        }, set: {
            collapsedSections = LibrarySectionExpansion.setting(title, expanded: $0,
                                                                in: collapsedSections)
        })
    }

    /// The drill's own long-press actions: read what it is, or fork it (Slice 3).
    private func menuItems(for exercise: Exercise) -> [PocketRowMenuItem] {
        [PocketRowMenuItem("Details", systemImage: "info.circle") { detailExercise = exercise },
         // "Add to folder…", never "Move to" (ADR 0210 D1) — a drill in two folders is the feature.
         PocketRowMenuItem("Add to folder…", systemImage: "folder.badge.plus") { filing = exercise },
         PocketRowMenuItem("Duplicate", systemImage: "plus.square.on.square") { duplicate(exercise) }]
    }

    private func favorite(for exercise: Exercise) -> PocketRowFavorite {
        PocketRowFavorite(isFavorite: exercise.isFavorite) { exercise.isFavorite.toggle() }
    }

    private func deletion(for exercise: Exercise) -> PocketRowDelete {
        PocketRowDelete(id: exercise.uid, name: displayName(exercise)) { context.delete(exercise) }
    }

    /// Fork a drill into an editable copy — the cheapest way to make a variant of a template you've
    /// already tuned (Slice 3). Copying is **authoring**, so it takes the same `canAuthor` gate as
    /// creation (ADR 0112): a free player can run the seeded Pro-template freebies but can't fork
    /// one into a drill of their own. The copy is inserted before its song links are assigned —
    /// a relationship can't be set on an un-inserted model.
    private func duplicate(_ exercise: Exercise) {
        guard AccessPolicy.canAuthor(exercise.template, isPro: isPro) else {
            return presentPaywall(.newExercise(exercise.template))
        }
        let name = CopyNaming.copyName(of: exercise.name, existing: exercises.map(\.name))
        let copy = exercise.duplicated(named: name)
        context.insert(copy)
        copy.linkedSongs = exercise.linkedSongs
        haptic(.medium)
    }

    /// One library row, entitlement-aware (ADR 0112): a runnable drill (free-tier template, a
    /// free-taste preset, or any drill for a Pro subscriber) pushes its run screen; a locked Pro drill
    /// stays **visible but badged** and taps to the paywall instead ("locked, not hidden"). The
    /// free-taste presets stay runnable here — only editing them is gated, on the run screen.
    @ViewBuilder
    private func exerciseRow(_ exercise: Exercise) -> some View {
        let runnable = AccessPolicy.canRun(
            exercise.template, isPro: isPro,
            isFreeTastePreset: AccessPolicy.isFreeTaste(slug: exercise.presetSlug))
        if runnable {
            NavigationLink { ExerciseRunScreen(exercise: exercise) } label: { row(exercise, locked: false) }
        } else {
            Button { presentPaywall(.proExercise) } label: { row(exercise, locked: true) }
                .buttonStyle(.plain)
        }
    }

    private func row(_ exercise: Exercise, locked: Bool) -> some View {
        HStack(spacing: 8) {
            PracticeUnitRow(
                title: exercise.name.isEmpty ? "Untitled" : exercise.name,
                progress: exercise.commandProgressLabel,
                isFavorite: exercise.isFavorite)
            if locked {
                Spacer(minLength: 8)
                Text("PRO")
                    .font(.futura(.caption2, weight: .bold))
                    .foregroundStyle(PocketColor.background)
                    .padding(.horizontal, 6).padding(.vertical, 1)
                    .background(Capsule().fill(PocketColor.practice))
                Image(systemName: "lock.fill")
                    .font(.futura(.caption, weight: .semibold))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        }
        .contentShape(Rectangle())
    }

    /// The command tempo a fresh exercise pre-fills (ADR 0113 S2 consumer): the profile's experience
    /// default when declared, else the engine floor — the same value `NewExerciseSheet` uses by
    /// default, so an untouched install is unchanged.
    private var defaultCommand: Int {
        profiles.first?.experience?.defaultCommandTempo ?? StandaloneMetronomeEngine.defaultCommandBPM
    }

    /// The instrument a fresh exercise picks up (ADR 0116 S2 consumer): the profile's preferred
    /// instrument when declared, else guitar — invisible today (no create-step toggle until S3), so an
    /// untouched install keeps making guitar drills exactly as before.
    private var defaultInstrument: Instrument {
        profiles.first?.preferredInstrument ?? .guitar
    }

    /// The message shown when nothing matches — favourites-aware so an empty favourites view reads
    /// as a prompt to pin something, not a false "no search matches".
    private var noMatchMessage: String {
        if favoritesOnly {
            return "No favourite exercises yet. Swipe or hold a drill and tap Favourite to pin it."
        }
        if searchText.isEmpty, !folderBrowse.path.isEmpty {
            return "Nothing filed in “\(FolderPath.leaf(folderBrowse.path))” yet. "
                 + "Hold a drill anywhere in your library and tap Add to folder…"
        }
        return "No exercises match “\(searchText)”."
    }

    /// Create an exercise from a confirmed `NewExercisePlan` (ADR 0046 / 0068) and stage it for its
    /// run screen. The insert itself is `plan.finalise(in:)` — **shared with the metronome
    /// automator's save seam**, the other host of this same sheet — so creation behaviour is written
    /// once. Everything left here is this host's own: the confirmation haptic and the push.
    private func create(_ plan: NewExercisePlan) {
        guard let exercise = plan.finalise(in: context) else { return }
        haptic(.medium)
        justCreated = exercise
    }

    /// Promote the just-created drill into a push, once the create sheet is actually gone. Locked Pro
    /// templates never open (the same `canRun` gate the rows use) — authoring one shouldn't be a way
    /// past the paywall; the drill is still there in the list, badged.
    private func openJustCreated() {
        guard let exercise = justCreated else { return }
        justCreated = nil
        guard AccessPolicy.canRun(exercise.template, isPro: isPro,
                                  isFreeTastePreset: AccessPolicy.isFreeTaste(slug: exercise.presetSlug))
        else { return }
        opening = exercise
    }

}
