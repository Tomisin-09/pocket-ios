import SwiftData
import SwiftUI

/// The **Journal space** (Wave 2, ADR 0100): a single, read-only practice-history timeline that
/// aggregates journal **notes** and audio **takes** across every owner — song loops (Library) and
/// exercises (Practice) alike. A top-level Home destination (the 4th nav strip), because the feed is
/// cross-cutting: it belongs above Practice and Library, not inside either.
///
/// Read-only by design — reflection, not authoring: writing/editing entries stays in the per-owner
/// `JournalSheet`. Takes are the exception, since playing one *is* their nature. All the merge /
/// filter / owner-label logic is the pure `JournalTimeline`; this view only queries, groups by day,
/// and renders.
struct JournalTabView: View {
    // Unfiltered queries (no optional `#Predicate` — those starve the main thread); the merge and
    // scope filter happen in memory via `JournalTimeline`.
    @Query(sort: \JournalEntry.createdAt, order: .reverse) private var entries: [JournalEntry]
    @Query(sort: \Recording.createdAt, order: .reverse) private var takes: [Recording]
    // The library, for resolving a session entry's practised-unit pills (ADR 0143). Those are loose
    // **id copies**, not relationships — that is what lets an entry outlive the units it names — so
    // there is nothing to follow and the uid has to be looked up. Unsorted and unfiltered, like the
    // two above and for the same reason.
    @Query private var exercises: [Exercise]
    @Query private var loops: [Loop]

    @State private var scope: JournalTimeline.Scope = .all
    /// Free-text search over song / loop / exercise / template / date (`JournalTimeline.searchHaystack`).
    @State private var query = ""
    /// Day order — newest-first by default; flip to walk the history forwards.
    @State private var sortOrder: JournalTimeline.SortOrder = .newest
    /// One take plays at a time; stopped on dismiss (mirrors `TakesSheet`). Not `private`: the
    /// deletion glue lives in `JournalTabView+Deletion.swift`, and `private` is file-scoped.
    @State var player = RecordingPlayer()
    /// The unit an owner caption is opening (ADR 0142), or `nil`. Keyed on the unit's stable `uid`
    /// through `JournalOwnerRoute`, never `persistentModelID` (ADR 0090).
    @State private var openingOwner: JournalOwnerRoute?
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
    /// The take being named, by stable `uid` — never `persistentModelID` (ADR 0090).
    @State private var renaming: StableRef<Recording>?

    /// The scope- then search-filtered feed, minus anything awaiting deletion. Filtering here rather
    /// than at the row is what makes `sections` and the empty state follow automatically.
    private var items: [JournalTimeline.Item] {
        let merged = JournalTimeline.merge(entries: entries, takes: takes)
            .filter { !rowDeletion.isPending($0.id) }
        return JournalTimeline.filter(JournalTimeline.filter(merged, scope: scope), query: query)
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
            // Progress lives behind the same door as the timeline: both are read-only practice
            // history, so ADR 0117's screen is reached from here rather than from a new Home card —
            // which keeps Home's grouped layout (ADR 0102) unchanged until the deferred year tier and
            // card evolution land together. A fixed-width glyph, per the toolbar grammar (ADR 0126).
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    PracticeProgressView()
                } label: {
                    Image(systemName: "chart.bar.xaxis")
                }
                .accessibilityLabel("Progress")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Picker("Sort", selection: $sortOrder) {
                        Label("Newest first", systemImage: "arrow.down").tag(JournalTimeline.SortOrder.newest)
                        Label("Oldest first", systemImage: "arrow.up").tag(JournalTimeline.SortOrder.oldest)
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
                .accessibilityLabel("Sort order")
            }
        }
        .navigationDestination(item: $openingOwner) { route in
            JournalOwnerDestinationView(route: route)
        }
        .onDisappear { player.stop() }
    }

    /// Follow an item's owner caption (ADR 0142). A locked Pro drill opens the paywall instead of its
    /// run screen — the same `canRun` gate `ExerciseLibraryView`'s rows apply, since a player who
    /// wrote notes while subscribed keeps the notes when the subscription lapses.
    private func openOwner(of item: JournalTimeline.Item) {
        guard let route = JournalOwnerRoute.route(for: item) else { return }
        open(route)
    }

    /// The caption's tap action, or `nil` when the item has nowhere to go — a song-owned take, or a
    /// loop whose audio no longer resolves. `nil` keeps the caption as plain text.
    private func openAction(for item: JournalTimeline.Item) -> (() -> Void)? {
        guard JournalOwnerRoute.route(for: item) != nil else { return nil }
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

    /// Follow a resolved route, honouring the Pro run gate.
    private func open(_ route: JournalOwnerRoute) {
        if case .exercise(let exercise) = route,
           !AccessPolicy.canRun(exercise.template, isPro: isPro,
                                isFreeTastePreset: AccessPolicy.isFreeTaste(slug: exercise.presetSlug)) {
            presentPaywall(.proExercise)
            return
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

    private var list: some View {
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
    }

    @ViewBuilder private func row(_ item: JournalTimeline.Item) -> some View {
        switch item {
        case .note(let entry):
            JournalEntryRow(entry: entry, ownerLabel: JournalTimeline.ownerLabel(for: item),
                            onOpenOwner: openAction(for: item),
                            openUnit: openAction(for:))
                .swipeActions(edge: .trailing) { deleteButton(for: item) }
        case .take(let take):
            JournalTakeRow(take: take,
                           ownerLabel: JournalTimeline.ownerLabel(for: item),
                           onOpenOwner: openAction(for: item),
                           isPlaying: player.isPlaying(take.fileName)) {
                player.toggle(take.fileName)
            }
            .swipeActions(edge: .trailing) { deleteButton(for: item) }
            // Naming is a take-only verb: every other row already says what it is in its own words.
            .swipeActions(edge: .leading) {
                Button { renaming = StableRef(value: take) } label: {
                    Label("Rename", systemImage: "pencil")
                }
                .tint(PocketColor.journal)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: searching ? "magnifyingglass" : "book.closed")
                .font(.futura(.largeTitle))
                .foregroundStyle(PocketColor.textSecondary)
            Text(emptyTitle)
                .font(.futura(.headline))
                .foregroundStyle(PocketColor.textPrimary)
            Text(emptyMessage)
                .font(.futura(.subheadline))
                .foregroundStyle(PocketColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// Whether a live search is narrowing the feed (drives the "no matches" empty state).
    private var searching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var emptyTitle: String {
        if searching { return "No matches" }
        switch scope {
        case .all: return "Nothing here yet"
        case .notes: return "No notes yet"
        case .takes: return "No takes yet"
        }
    }

    private var emptyMessage: String {
        if searching {
            return "Nothing matches “\(query)”. Try a song, exercise, template, or date."
        }
        switch scope {
        case .all:
            return "Notes you write and takes you record — on your loops and exercises — gather here."
        case .notes:
            return "Jot a goal, a breakthrough, or a struggle after a run and it shows up here."
        case .takes:
            return "Arm recording next to Start training to capture your playing."
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
            for: Song.self, Loop.self, Exercise.self, JournalEntry.self, Recording.self,
            PracticeRun.self,
            configurations: .init(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let now = Date()

        let song = Song.sample()
        song.title = "Little Wing"
        song.artist = "Jimi Hendrix"
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
        context.insert(breakthrough)

        let struggle = JournalEntry.forLoop(text: "Barre still buzzing on the B string.",
                                            kind: .struggle, masteryAtEntry: 3,
                                            commandTempoAtEntry: 0.9,
                                            createdAt: now.addingTimeInterval(-86_400))
        struggle.loop = loop
        context.insert(struggle)

        let take = Recording(fileName: "demo.m4a", duration: 48,
                             createdAt: now.addingTimeInterval(-7200), loop: loop)
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
