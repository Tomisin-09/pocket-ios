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
    @Environment(\.modelContext) private var context
    /// Red Moon Pro entitlement + the shared paywall (ADR 0112); safe preview defaults (free / no-op).
    @Environment(\.isPro) private var isPro
    @Environment(\.presentPaywall) private var presentPaywall
    /// Deferred, undoable row deletion (Slice 3). **Owned here, not by the modifier**: this view
    /// reads `isPending` itself to filter out a row awaiting its delete, and a modifier applied
    /// inside `body` can only publish to its descendants.
    @State private var rowDeletion = RowDeletionCoordinator()
    @Query private var exercises: [Exercise]
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
    /// Sort key + direction, persisted across launches (ADR 0056).
    @AppStorage("exerciseLibrarySort") private var sortKey: ExerciseSortKey = .name
    @AppStorage("exerciseLibrarySortAscending") private var sortAscending = true
    @State private var searchText = ""
    /// Whether the list is narrowed to favourited drills (ADR 0119) — a session toggle, not persisted.
    @State private var favoritesOnly = false
    /// The active instrument filter (ADR 0116 S4), `nil` = "All". Purely a session filter — not
    /// persisted, since it's only reachable once the library holds more than one instrument, and it
    /// resets whenever that stops being true (`showsInstrumentFilter`).
    @State private var instrumentFilter: Instrument?

    /// The drills actually on screen — everything except rows whose delete is pending behind the
    /// Undo toast (Slice 3). The empty state reads from here too, so deleting your last drill says
    /// "no exercises yet" rather than "nothing matches your search".
    private var presentExercises: [Exercise] {
        exercises.filter { !rowDeletion.isPending($0.uid) }
    }

    /// The exercises narrowed by search **and** the active instrument filter, then grouped into
    /// **template sections** (ADR 0068), each ordered by the current sort — the sectioned list the
    /// user sees, and what deletion indexes into (per section).
    private var sections: [LibrarySection<Exercise>] {
        let matched = presentExercises.filter {
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

    private func fields(for exercise: Exercise) -> ExerciseSortFields {
        ExerciseSortFields(name: exercise.name, command: exercise.command,
                           dateAdded: exercise.dateAdded,
                           notesPerBeat: exercise.noteRate?.perBeat ?? 1,
                           templateName: exercise.template.displayName,
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
                Text(noMatchMessage)
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else {
                ForEach(sections, id: \.title) { section in
                    Section(section.title) {
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
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        // Deferred delete + the Undo toast for every row on this screen (Slice 3).
        .pocketRowUndoHost(rowDeletion)
        .safeAreaInset(edge: .top) {
            if showsInstrumentFilter {
                InstrumentFilterBar(instruments: presentInstruments, selection: $instrumentFilter)
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
            if !presentExercises.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    LibraryOptionsMenu(favoritesOnly: $favoritesOnly, sortControls: {
                        LibrarySortPickers(sortKey: $sortKey, ascending: $sortAscending)
                    })
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true; haptic(.light) } label: {
                    Image(systemName: "plus")
                }
                .tint(PocketColor.practice)
                .accessibilityLabel("New exercise")
            }
        }
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
            if let exercise = opening { ExerciseRunView(exercise: exercise) }
        }
        // Details, from the row's long-press menu. Bool-bound rather than `.sheet(item:)` for the
        // ADR 0090 reason the whole app now follows: a model's `persistentModelID` can flip on a
        // save mid-edit and dismiss an item-based sheet.
        .sheet(isPresented: Binding(get: { detailExercise != nil },
                                    set: { if !$0 { detailExercise = nil } })) {
            if let exercise = detailExercise { ExerciseDetailSheet(exercise: exercise) }
        }
    }

    private func displayName(_ exercise: Exercise) -> String {
        exercise.name.isEmpty ? "Untitled" : exercise.name
    }

    /// The drill's own long-press actions: read what it is, or fork it (Slice 3).
    private func menuItems(for exercise: Exercise) -> [PocketRowMenuItem] {
        [PocketRowMenuItem("Details", systemImage: "info.circle") { detailExercise = exercise },
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
            NavigationLink { ExerciseRunView(exercise: exercise) } label: { row(exercise, locked: false) }
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
        favoritesOnly ? "No favourite exercises yet. Swipe or hold a drill and tap Favourite to pin it."
                      : "No exercises match “\(searchText)”."
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

#Preview("Exercises — with units") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(for: Exercise.self,
                                        configurations: .init(isStoredInMemoryOnly: true))
    container.mainContext.insert(Exercise(name: "Alternating picking",
                                          currentTempo: 70, commandTempo: 96, template: .picking))
    container.mainContext.insert(Exercise(name: "Spider", currentTempo: 60, template: .warmup))
    container.mainContext.insert(Exercise(name: "Down Up Down", currentTempo: 80,
                                          template: .strumming))
    // A bass exercise trips the progressive-disclosure instrument filter (ADR 0116 S4).
    container.mainContext.insert(Exercise(name: "E minor pentatonic", currentTempo: 60,
                                          template: .scales, instrument: .bass))
    return NavigationStack { ExerciseLibraryView() }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
