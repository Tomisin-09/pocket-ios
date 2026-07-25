import SwiftData
import SwiftUI

/// The **Exercises** library inside Practice (ADR 0046): the focused list of click-only,
/// command-anchored drills — your own plus the seeded starters — pushed from the Practice hub.
/// Owns exercise **creation** (the `+` → `NewExerciseSheet`) and **deletion** (swipe), since
/// exercises live here and nowhere else. Tapping one opens its `ExerciseRunView`.
///
/// Relies on an ambient `NavigationStack` (Practice → Home's stack), like the hub. Sort key +
/// direction and the search query narrow the list in memory (ADR 0056) via the pure
/// `PracticeLibrarySort`, so `@Query` stays unsorted and deletion indexes the *displayed* list.
struct ExerciseLibraryView: View {
    @Environment(\.modelContext) private var context
    @Query private var exercises: [Exercise]
    /// The local profile (ADR 0113 S2): its self-rated experience seeds a new exercise's default
    /// command tempo, so a beginner starts near the floor and a seasoned player higher up.
    @Query private var profiles: [Profile]
    @State private var creating = false
    /// Sort key + direction, persisted across launches (ADR 0056).
    @AppStorage("exerciseLibrarySort") private var sortKey: ExerciseSortKey = .name
    @AppStorage("exerciseLibrarySortAscending") private var sortAscending = true
    @State private var searchText = ""
    /// The active instrument filter (ADR 0116 S4), `nil` = "All". Purely a session filter — not
    /// persisted, since it's only reachable once the library holds more than one instrument, and it
    /// resets whenever that stops being true (`showsInstrumentFilter`).
    @State private var instrumentFilter: Instrument?

    /// The exercises narrowed by search **and** the active instrument filter, then grouped into
    /// **template sections** (ADR 0068), each ordered by the current sort — the sectioned list the
    /// user sees, and what deletion indexes into (per section).
    private var sections: [LibrarySection<Exercise>] {
        let matched = exercises.filter {
            PracticeLibrarySort.exerciseMatches(fields(for: $0), query: searchText,
                                                instrument: activeInstrumentFilter)
        }
        return PracticeLibrarySort.exerciseSections(matched, sortedBy: sortKey,
                                                    ascending: sortAscending, fields: fields(for:))
    }

    /// Whether any exercise matches the current search — drives the empty vs no-match states.
    private var hasMatches: Bool { sections.contains { !$0.items.isEmpty } }

    /// The distinct instruments present in the library, canonical order (ADR 0116 S4).
    private var presentInstruments: [Instrument] {
        PracticeLibrarySort.instrumentsPresent(exercises.map(\.instrument))
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
                           templateName: exercise.template.displayName,
                           instrument: exercise.instrument)
    }

    var body: some View {
        List {
            if exercises.isEmpty {
                Text("No exercises yet. Tap + to create one — a named drill you push faster "
                     + "over time.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else if !hasMatches {
                Text("No exercises match “\(searchText)”.")
                    .font(.futura(.footnote))
                    .foregroundStyle(PocketColor.textSecondary)
                    .listRowBackground(PocketColor.background)
            } else {
                ForEach(sections, id: \.title) { section in
                    Section(section.title) {
                        ForEach(section.items) { exercise in
                            NavigationLink {
                                ExerciseRunView(exercise: exercise)
                            } label: {
                                PracticeUnitRow(
                                    title: exercise.name.isEmpty ? "Untitled" : exercise.name,
                                    progress: "Command \(exercise.command) → "
                                        + "\(exercise.reachTempo) BPM")
                            }
                            .listRowBackground(PocketColor.background)
                        }
                        .onDelete { delete($0, in: section.items) }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        .safeAreaInset(edge: .top) {
            if showsInstrumentFilter { instrumentFilterBar }
        }
        .onChange(of: showsInstrumentFilter) { _, shows in
            // Once the library drops back to a single instrument, forget any selection so it can't
            // re-narrow the list if a second instrument is added again later.
            if !shows { instrumentFilter = nil }
        }
        .navigationTitle("Exercises")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Exercises")
        .toolbar {
            if !exercises.isEmpty {
                ToolbarItem(placement: .topBarLeading) { sortMenu }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { creating = true; haptic(.light) } label: {
                    Image(systemName: "plus")
                }
                .tint(PocketColor.practice)
                .accessibilityLabel("New exercise")
            }
        }
        .sheet(isPresented: $creating) {
            NewExerciseSheet(initialCommand: defaultCommand, defaultInstrument: defaultInstrument,
                             onCreate: create)
        }
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

    /// The progressive-disclosure instrument filter (ADR 0116 S4) — an "All" chip plus one per
    /// instrument present, pinned above the list. Shown only when the library holds more than one
    /// instrument (`showsInstrumentFilter`); tapping a chip narrows the sections to that instrument.
    private var instrumentFilterBar: some View {
        HStack(spacing: 8) {
            instrumentChip(title: "All", isSelected: instrumentFilter == nil) { instrumentFilter = nil }
            ForEach(presentInstruments) { instrument in
                instrumentChip(title: instrument.displayName,
                               isSelected: instrumentFilter == instrument) {
                    instrumentFilter = instrument
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(PocketColor.background)
    }

    /// One filter chip — a pill that fills with the Practice tint when selected.
    private func instrumentChip(title: String, isSelected: Bool,
                                action: @escaping () -> Void) -> some View {
        Button {
            action()
            haptic(.light)
        } label: {
            Text(title)
                .font(.futura(.subheadline))
                .foregroundStyle(isSelected ? PocketColor.background : PocketColor.textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(
                    Capsule().fill(isSelected ? PocketColor.practice : PocketColor.surfaceStandard)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) exercises")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    /// The sort control — a menu whose label spells out the active key with a direction arrow
    /// (ADR 0056, mirroring the song library and the loop library).
    private var sortMenu: some View {
        Menu {
            Picker("Sort by", selection: $sortKey) {
                ForEach(ExerciseSortKey.allCases) { key in
                    Text(key.label).tag(key)
                }
            }
            Picker("Order", selection: $sortAscending) {
                Label("Ascending", systemImage: "arrow.up").tag(true)
                Label("Descending", systemImage: "arrow.down").tag(false)
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                Text(sortKey.label)
            }
            .tint(PocketColor.practice)
        }
        .accessibilityLabel("Sort by \(sortKey.label), \(sortAscending ? "ascending" : "descending")")
    }

    /// Create an exercise from a confirmed `NewExercisePlan` (ADR 0046 / 0068): anchored on the
    /// entered **command** tempo (the warm-up working floor and the reach derive from it via pure
    /// `TempoStretch`, so the typed number is the command shown on the run screen), carrying the
    /// chosen **template** (which groups the library and picks the run surface) and meter (so the run
    /// metronome accents + count-in match, ADR 0052). A strumming or fretboard template's authored
    /// payload (pattern / drill) is encoded onto the exercise.
    private func create(_ plan: NewExercisePlan) {
        guard !plan.name.isEmpty else { return }
        let exercise = Exercise.commandAnchored(name: plan.name, command: plan.command,
                                                beatsPerBar: plan.signature.beats,
                                                noteValue: plan.signature.noteValue,
                                                template: plan.template,
                                                instrument: plan.instrument)
        if let strum = plan.strum { exercise.setStrumPattern(strum) }
        if let fretboard = plan.fretboard { exercise.setFretboardContent(fretboard) }
        if let chords = plan.chords { exercise.setChordProgression(chords) }
        if let strumChords = plan.strumChords { exercise.setStrumChordSheet(strumChords) }
        context.insert(exercise)
        haptic(.medium)
    }

    /// Delete indexes into the *displayed* section's items — the offsets `onDelete` reports are
    /// section-relative, so the section's own array is the one to index (ADR 0056 pattern).
    private func delete(_ offsets: IndexSet, in items: [Exercise]) {
        for index in offsets { context.delete(items[index]) }
        haptic(.medium)
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
