import SwiftData
import SwiftUI

/// The **Journal space** (Wave 2, ADR 0100): a single, read-only practice-history timeline that
/// aggregates journal **notes** and audio **takes** across every owner — song loops (Library) and
/// exercises (Practice) alike. A top-level Home destination (the 4th nav strip), because the feed is
/// cross-cutting: it belongs above Practice and Library, not inside either.
///
/// Read-only for **owned** entries — reflection, not authoring: writing and editing an entry that
/// belongs to a loop, an exercise or a session stays on that owner's screen, because that is the only
/// place its snapshot is honest. Takes are the exception, since playing one *is* their nature.
///
/// ADR 0155 §3 narrows that rule rather than overturning it: this space writes **standalone** notes,
/// and only standalone notes. What the ＋ cannot do is offer an owner picker — filing a note against a
/// unit at a moment you are not practising it would snapshot where that unit stands *now* rather than
/// where it stood when the thing being described happened, which is the exact dishonesty ADR 0100 §1
/// was protecting against.
///
/// All the merge / filter / owner-label logic is the pure `JournalTimeline`; this view only queries,
/// groups by day, and renders.
struct JournalTabView: View {
    // Unfiltered queries (no optional `#Predicate` — those starve the main thread); the merge and
    // scope filter happen in memory via `JournalTimeline`.
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    @Query(sort: \Recording.createdAt, order: .reverse) private var takes: [Recording]
    // The library, for resolving a session entry's practised-unit pills (ADR 0143) **and its routine
    // caption**. Those are loose **id copies**, not relationships — that is what lets an entry outlive
    // the units it names — so there is nothing to follow and the uid has to be looked up. Unsorted and
    // unfiltered, like the two above and for the same reason.
    @Query private var exercises: [Exercise]
    @Query private var loops: [Loop]
    @Query private var routines: [Routine]

    /// Which medium the feed shows. Not `private`: `private` is file-scoped, and the empty state
    /// that has to *name* this filter lives in `JournalTabView+EmptyState.swift` (and the menu that
    /// sets the other three in `JournalTabView+Options.swift`).
    ///
    /// **Persisted, along with the sort and both filters below** (ADR 0190 D8). Every other list
    /// filter in the app is transient `@State` that resets on each visit; this screen persists
    /// because it earns it under one rule — *a filter may persist exactly when the screen shows,
    /// unopened, that it is in force.* The segmented control shows itself; the menu's two filters show
    /// themselves through the filled options glyph, and the empty state names whichever emptied the
    /// screen. The literal in each initialiser is what SwiftUI actually uses for an unset key, so
    /// every one of them reads the enum's own `default` rather than repeating a value.
    @AppStorage(AppSettings.Key.journalScope) var scope = JournalTimeline.Scope.default
    /// Free-text search over song / loop / exercise / template / date (`JournalTimeline.searchHaystack`).
    /// Deliberately **not** persisted: a search is a question you are asking now, and it is the one
    /// filter with no unopened resting state to show — the field empties itself when you leave.
    @State var query = ""
    /// Day order — newest-first by default; flip to walk the history forwards. Not `private`: the
    /// menu that sets it lives in `JournalTabView+Options.swift`.
    @AppStorage(AppSettings.Key.journalSortOrder) var sortOrder = JournalTimeline.SortOrder.default
    /// Show only what the player has pinned (ADR 0190 D4).
    @AppStorage(AppSettings.Key.journalPinnedOnly) var pinnedOnly = false
    /// Which **owner kinds** the feed shows — *just my session notes*, or session **and** loop notes
    /// together (ADR 0190 D5, D10). Empty by default, which means everything; ticking kinds widens.
    @AppStorage(AppSettings.Key.journalOwnerFilter)
    var ownerFilter = JournalTimeline.OwnerSelection.default
    /// Whether the owner-kind sheet is up. A sheet rather than a submenu because the facet is
    /// multi-select: every tap in a popup `Menu` dismisses it (ADR 0190 D10).
    @State var choosingKinds = false
    /// The standalone-note composer (ADR 0155 §3).
    @State private var composing = false
    /// Whether the Practice log screen is pushed. Still a flag rather than a `NavigationLink`: the
    /// row that sets it sits outside the `List`, in the same `VStack` as the scope picker, and a bare
    /// `NavigationLink` there would draw list chrome that belongs to neither. Not `private`: the row
    /// lives in `JournalTabView+PracticeLog.swift`, and `private` is file-scoped.
    @State var showingPracticeLog = false
    /// One take plays at a time; stopped on dismiss (mirrors `TakesSheet`). Not `private`: the
    /// deletion glue lives in `JournalTabView+Deletion.swift`, and `private` is file-scoped.
    @State var player = RecordingPlayer()
    /// The unit an owner caption is opening (ADR 0142), or `nil`. Keyed on the unit's stable `uid`
    /// through `JournalOwnerRoute`, never `persistentModelID` (ADR 0090).
    @State private var openingOwner: JournalOwnerRoute?
    /// The take pushed onto its own screen (ADR 0174), keyed on the stable `uid` like every other
    /// model presentation here.
    @State private var openedTake: StableRef<Recording>?
    /// Red Moon Pro entitlement + the shared paywall (ADR 0112) — the caption link honours the same
    /// run gate the exercise library's rows do, so a note is never a way past it.
    @Environment(\.isPro) private var isPro
    @Environment(\.presentPaywall) private var presentPaywall
    /// For this space's write verbs — deleting any entry, and naming a take (ADR 0100 amendment).
    @Environment(\.modelContext) var modelContext
    /// Deferred, undoable deletion — screen-owned, like every library list's. Deferral is what makes
    /// deleting a *take* offerable at all: its audio file is only removed once the window closes, so
    /// nothing irreversible happens while Undo is still on screen.
    @State var rowDeletion = RowDeletionCoordinator()
    /// The take being named, by stable `uid` — never `persistentModelID` (ADR 0090). Not `private`:
    /// the hold menu that sets it lives in `JournalTabView+Deletion.swift`.
    @State var renaming: StableRef<Recording>?
    /// Whether the **Jump to…** date picker is up (ADR 0190 D9). Not `private`: the menu item and the
    /// sheet both live in `JournalTabView+Options.swift`.
    @State var jumping = false
    /// The day that picker is sitting on. Seeded from the feed each time the sheet opens, so it
    /// starts somewhere the journal actually reaches rather than on today by default.
    @State var jumpDay = Date()
    /// The day section the list has been asked to scroll to, consumed and cleared by the
    /// `ScrollViewReader` in `list`. A one-shot signal rather than a stored position: the feed's
    /// resting state is wherever the player left it, and a persisted scroll target would fight that
    /// every time a filter changed the sections underneath it.
    @State var scrollTarget: Date?

    /// The scope- then search-filtered feed, minus anything awaiting deletion. Filtering here rather
    /// than at the row is what makes `sections` and the empty state follow automatically.
    private var items: [JournalTimeline.Item] {
        let merged = JournalTimeline.merge(entries: entries, takes: takes)
            .filter { !rowDeletion.isPending($0.id) }
        let scoped = JournalTimeline.filter(merged, scope: scope)
        let owned = JournalTimeline.filter(scoped, owner: ownerFilter)
        let pinned = JournalTimeline.filter(owned, pinnedOnly: pinnedOnly)
        return JournalTimeline.filter(pinned, query: query)
    }

    /// Day-sectioned for display (pure helper, shared with `JournalSheet`); `oldest` reverses both the
    /// day order and the within-day order.
    private var sections: [JournalGrouping.DaySection<JournalTimeline.Item>] {
        let grouped = JournalGrouping.byDay(items) { $0.date }
        switch sortOrder {
        case .newest:
            return grouped
        case .oldest:
            return grouped.reversed().map {
                JournalGrouping.DaySection(day: $0.day, entries: Array($0.entries.reversed()))
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            scopePicker
            if !searching { practiceLogRow }
            if sections.isEmpty { emptyState } else { list }
        }
        // Above the list-vs-empty-state branch on purpose: deleting the last row swaps the `List` for
        // the empty state, and a host applied inside either branch would take the toast with it.
        .pocketRowUndoHost(rowDeletion)
        .renameTakeAlert($renaming, context: modelContext)
        // Cap to a readable column at regular width (iPad / landscape); no-op at compact
        // width, dormant on the iPhone-only v1 build (ADR 0105).
        .readableWidth()
        .navigationTitle("Journal")
        .navigationBarTitleDisplayMode(.inline)
        .background(PocketColor.background.ignoresSafeArea())
        .searchable(text: $query, prompt: "Search by song, exercise, template or date")
        .toolbar {
            // ADR 0126's grammar is `ellipsis.circle` then `+`, and three bare trailing items is
            // exactly the shape it was written to stop (ADR 0155, the open toolbar question). That
            // resolution folded **both** Progress and Sort into this menu, which cost the practice
            // log its discoverability — ADR 0176 gives it a row on the screen instead, and the menu
            // keeps only Sort, a two-state flip that isn't even persisted and had the weakest claim
            // on a top-level slot all along.
            // The menu itself is `JournalTabView+Options.swift` — it grew a second filter with ADR
            // 0190 S2 and took this file past the 400-line cap.
            ToolbarItem(placement: .topBarTrailing) { optionsMenu }
            ToolbarItem(placement: .topBarTrailing) {
                QuickJournalButton(isPresented: $composing)
            }
        }
        .navigationDestination(item: $openingOwner) { route in
            JournalOwnerDestinationView(route: route)
        }
        // The take's own screen (ADR 0174), carrying this space's shared player so a take auditioned
        // from the feed and then opened is still the one playing. Delete goes back through the
        // feed's deferred, undoable path — the audio file is only removed once the toast closes.
        .navigationDestination(item: $openedTake) { ref in
            TakeDetailView(take: ref.value, player: player) { requestDelete(.take(ref.value)) }
        }
        // The row sets a flag and the push happens out here, so the destination is declared once
        // whether the timeline or the empty state is on screen (ADR 0176).
        .navigationDestination(isPresented: $showingPracticeLog) { PracticeLogView() }
        // The Journal space's own write seam (ADR 0155 §3): standalone notes, and *only* standalone
        // notes. No owner picker — filing a note against a unit you are not currently practising is
        // what makes a snapshot dishonest, and that prohibition outlives this screen.
        .sheet(isPresented: $composing) {
            QuickJournalSheet(owner: .standalone)
        }
        // Jump to a date (ADR 0190 D9) — the sheet and its rule live in `JournalTabView+Options`.
        .sheet(isPresented: $jumping) { jumpSheet }
        // The owner-kind facet (ADR 0190 D5, D10), in the same file.
        .sheet(isPresented: $choosingKinds) { ownerFilterSheet }
        .onDisappear { player.stop() }
    }

    /// Follow an item's owner caption (ADR 0142). A locked Pro drill opens the paywall instead of its
    /// run screen — the same `canRun` gate `ExerciseLibraryView`'s rows apply, since a player who
    /// wrote notes while subscribed keeps the notes when the subscription lapses.
    private func openOwner(of item: JournalTimeline.Item) {
        guard let route = JournalOwnerRoute.route(for: item, routines: routines) else { return }
        open(route)
    }

    /// The caption's tap action, or `nil` when the item has nowhere to go — a song-owned take, a loop
    /// whose audio no longer resolves, or a session whose routine has been deleted. `nil` keeps the
    /// caption as plain text.
    private func openAction(for item: JournalTimeline.Item) -> (() -> Void)? {
        guard JournalOwnerRoute.route(for: item, routines: routines) != nil else { return nil }
        return { openOwner(of: item) }
    }

    /// The tap action for one of a session entry's practised-unit pills (ADR 0143), or `nil` when the
    /// unit was deleted since the session — the pill then renders dimmed rather than as a promise the
    /// tap can't keep. Applies the **same paywall gate** as the owner caption: notes written while
    /// subscribed survive a lapse, and must not become a way around it (ADR 0142 J5c).
    private func openAction(for ref: SessionUnitRef) -> (() -> Void)? {
        guard let route = JournalOwnerRoute.route(for: ref, exercises: exercises, loops: loops)
        else { return nil }
        return { open(route) }
    }

    /// Follow a resolved route, honouring the Pro gate. A note written while subscribed survives a
    /// lapse — but following it must not become a way around the gate (ADR 0142 J5c), so each kind is
    /// checked against the same policy its own library applies: `canRun` for an exercise, and
    /// `canEditRoutine` for a routine, since the editor is where a session caption lands.
    private func open(_ route: JournalOwnerRoute) {
        switch route {
        case .exercise(let exercise):
            guard AccessPolicy.canRun(exercise.template, isPro: isPro,
                                      isFreeTastePreset: AccessPolicy.isFreeTaste(slug: exercise.presetSlug))
            else { return presentPaywall(.proExercise) }
        case .routine(let routine):
            guard AccessPolicy.canEditRoutine(
                isPro: isPro,
                isFreeTasteRoutine: AccessPolicy.isFreeTasteRoutine(slug: routine.presetSlug))
            else { return presentPaywall(.routine(.edit)) }
        case .loop:
            break
        }
        openingOwner = route
    }

    // MARK: - Scope filter

    private var scopePicker: some View {
        Picker("Show", selection: $scope) {
            Text("All").tag(JournalTimeline.Scope.all)
            Text("Notes").tag(JournalTimeline.Scope.notes)
            Text("Takes").tag(JournalTimeline.Scope.takes)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    // MARK: - List

    /// Wrapped in a `ScrollViewReader` for **Jump to…** (ADR 0190 D9). The `ForEach` is already keyed
    /// by day, so each section's view id *is* the day and `scrollTo` needs no second identifier —
    /// which is also why the jump filters nothing: the days either side stay exactly where they are,
    /// and that is the whole difference between jumping to a date and searching for one.
    private var list: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(sections, id: \.day) { section in
                    Section(dayHeader(section.day)) {
                        ForEach(section.entries) { item in
                            row(item).listRowBackground(PocketColor.background)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            // Cleared as it is consumed, so asking for the same day twice scrolls twice — with the
            // value left set, the second request would be no change at all and simply not fire.
            .onChange(of: scrollTarget) { _, day in
                guard let day else { return }
                withAnimation { proxy.scrollTo(day, anchor: .top) }
                scrollTarget = nil
            }
        }
    }

    /// The days the feed is currently showing — what a jump can land on, and what bounds its picker.
    /// Read from `sections` rather than from every entry: you can only jump to a day that is on
    /// screen, so a picker offering days the filters have removed would be offering a dead end.
    var visibleDays: [Date] { sections.map(\.day) }

    @ViewBuilder private func row(_ item: JournalTimeline.Item) -> some View {
        switch item {
        case .note(let entry):
            JournalEntryRow(entry: entry, ownerLabel: JournalTimeline.ownerLabel(for: item),
                            onOpenOwner: openAction(for: item),
                            openUnit: openAction(for:))
                .contextMenu { holdMenu(for: item) }
        case .take(let take):
            JournalTakeRow(take: take,
                           ownerLabel: JournalTimeline.ownerLabel(for: item),
                           onOpenOwner: openAction(for: item),
                           isPlaying: player.isPlaying(take.fileName),
                           onToggle: { player.toggle(take.fileName) },
                           onOpen: { openedTake = StableRef(value: take) })
            // Naming is a take-only verb: every other row already says what it is in its own words.
            // It also survives as a swipe where **delete** doesn't, because renaming destroys nothing.
            .swipeActions(edge: .leading) {
                Button { renaming = StableRef(value: take) } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .tint(PocketColor.journal)
            }
            .contextMenu { holdMenu(for: item) }
        }
    }

    // MARK: - Day header

    /// "Today" / "Yesterday" / a medium date for a section's day (mirrors `JournalSheet`).
    private func dayHeader(_ day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) { return "Today" }
        if calendar.isDateInYesterday(day) { return "Yesterday" }
        return day.formatted(date: .abbreviated, time: .omitted)
    }
}

#Preview("Journal — mixed") {
    NavigationStack { JournalTabView() }
        .modelContainer(JournalTabPreview.container())
        .preferredColorScheme(.dark)
}

// Regular-width variant (ADR 0105): caps to a centred column at iPad / landscape width.
#Preview("Journal — regular width (iPad groundwork)") {
    NavigationStack { JournalTabView() }
        .modelContainer(JournalTabPreview.container())
        .environment(\.horizontalSizeClass, .regular)
        .frame(width: 1024, height: 900)
}

/// Seeds an in-memory store with a mixed feed (loop + exercise notes and a take) for the preview.
/// Kept in a helper so the `#Preview` body stays a single view expression.
private enum JournalTabPreview {
    @MainActor static func container() -> ModelContainer {
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(
            for: Song.self, Loop.self, Exercise.self, JournalEntry.self, Recording.self, TakeNote.self,
            PracticeRun.self,
            configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let now = Date()

        let song = Song.sample()
        song.title = "Slow Bend"
        song.artist = "Jack Trader"
        let loop = Loop(name: "Verse riff", start: 0.2, end: 0.35, speed: 0.9, repeats: 4)
        loop.mastery = 3
        loop.commandTempo = 0.9
        song.loops = [loop]
        context.insert(song)

        let drill = Exercise(name: "Chords", currentTempo: 84, commandTempo: 96)
        context.insert(drill)

        let breakthrough = JournalEntry.forExercise(text: "Clean run at 90% — finally locked it.",
                                                    kind: .breakthrough, commandBpmAtEntry: 96,
                                                    createdAt: now.addingTimeInterval(-3600))
        breakthrough.exercise = drill
        // Pinned in the seed (ADR 0190) so the canvas shows the gold `PinnedGlyph` on a note row
        // without anyone having to drive the hold menu to see it.
        breakthrough.isPinned = true
        context.insert(breakthrough)

        let struggle = JournalEntry.forLoop(text: "Barre still buzzing on the B string.",
                                            kind: .struggle, masteryAtEntry: 3,
                                            commandTempoAtEntry: 0.9,
                                            createdAt: now.addingTimeInterval(-86_400))
        struggle.loop = loop
        context.insert(struggle)

        let take = Recording(fileName: "demo.m4a", duration: 48,
                             createdAt: now.addingTimeInterval(-7200), loop: loop)
        // The take is pinned too: the mark has to read identically on both row kinds (ADR 0190 D2),
        // and a preview showing only one of them would hide exactly the drift that matters.
        take.isPinned = true
        context.insert(take)

        // A session entry (ADR 0143), with one pill that resolves and one that doesn't — the deleted
        // unit is the case worth seeing, since it's what an old entry looks like months later.
        let session = JournalEntry.forSession(
            text: "Shoulders tight for the first twenty minutes. Chord changes only came good at the end.",
            kind: .session, routineUID: UUID(), routineName: "Morning warm-up",
            units: [SessionUnitRef(uid: drill.uid, title: "Chords", kind: .exercise),
                    SessionUnitRef(uid: loop.uid, title: "Verse riff", kind: .loop),
                    SessionUnitRef(uid: UUID(), title: "Deleted drill", kind: .exercise)],
            createdAt: now.addingTimeInterval(-1800))
        context.insert(session)

        try? context.save()
        return container
    }
}
