import SwiftData
import SwiftUI

/// The **routine detail / editor** (ADR 0066, slice 2; edit-gating ADR 0071): view one `Routine`,
/// and — only after tapping **Edit** — name it, add exercise/loop blocks and rests, reorder them
/// (drag writes the explicit `order`, R2), and remove blocks. Viewing is read-only; **every mutation
/// is gated behind Edit**, so you can't change a routine by accident, and the add/insert/delete
/// affordances only appear in edit mode.
///
/// **Edits are sandboxed.** Editing happens in a private child `ModelContext` with autosave off, so
/// changes are provisional: **Save** commits them; **Cancel** discards them (rebuilding the sandbox
/// from the store) and returns to the read-only view. A brand-new routine opens straight in edit mode
/// and only lands in the library if you Save.
struct RoutineDetailView: View {
    @Environment(\.dismiss) private var dismiss
    /// The app's (main) context — used to resolve the routine for the player, so the run screens
    /// write to the real store, not this view's private editing sandbox.
    @Environment(\.modelContext) private var appContext

    /// The shared store — kept so Cancel can rebuild a clean sandbox that drops in-flight edits.
    private let container: ModelContainer
    /// Private editing scope over the shared store — never autosaves, so nothing persists until
    /// `saveEdits()` calls `save()` on it explicitly.
    @State private var editContext: ModelContext
    /// The routine under edit, resolved into (or created in) `editContext`.
    @State private var routine: Routine
    /// Whether this routine has been committed to the store yet — drives Cancel (discard vs dismiss)
    /// and the empty-new drop on Save. Flips true after the first Save of a new routine.
    @State private var existsInStore: Bool
    /// Read-only by default; every mutating control is revealed only in edit mode. A brand-new
    /// routine opens directly in edit mode (there's nothing to view yet).
    @State private var isEditing: Bool

    @State private var addingUnit = false
    /// The routine to run, resolved into the main context — drives the full-screen player. `nil`
    /// when not playing.
    @State private var playingRoutine: Routine?

    /// Build the sandbox. An existing routine is faulted into the child context by its id (opens
    /// read-only); a nil `existing` means a fresh routine created only in the sandbox, opened in edit
    /// mode and persisted iff you Save.
    init(container: ModelContainer, existing: Routine?) {
        self.container = container
        let context = ModelContext(container)
        context.autosaveEnabled = false
        _editContext = State(initialValue: context)
        if let existing, let local = context.model(for: existing.persistentModelID) as? Routine {
            _routine = State(initialValue: local)
            _existsInStore = State(initialValue: true)
            _isEditing = State(initialValue: false)
        } else {
            let fresh = Routine()
            context.insert(fresh)
            _routine = State(initialValue: fresh)
            _existsInStore = State(initialValue: false)
            _isEditing = State(initialValue: true)
        }
    }

    /// Build a **provisional generated session** for review (V2 planner Slices 1 & 3): materialise the
    /// pure generated blocks into a private sandbox (autosave off) so nothing persists until the user
    /// Saves or Starts. Opens read-only on the block list with the dated default name; backing out
    /// without committing discards the sandbox (nothing lands in the library). Fetches exercises,
    /// loops and songs so both a goal-less Quick session (Slice 1, exercise-only) and a goal session
    /// (Slice 3, which can surface loop/song candidates via Path B) resolve their blocks.
    init(container: ModelContainer, generatedSession blocks: [SessionBlock], defaultName: String) {
        self.container = container
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let exercises = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let loops = (try? context.fetch(FetchDescriptor<Loop>())) ?? []
        let songs = (try? context.fetch(FetchDescriptor<Song>())) ?? []
        let routine = PracticePlanner.materialise(blocks, name: defaultName, exercises: exercises,
                                                  loops: loops, songs: songs, into: context)
        _editContext = State(initialValue: context)
        _routine = State(initialValue: routine)
        _existsInStore = State(initialValue: false)
        _isEditing = State(initialValue: false)
    }

    /// The next explicit order value — one past the current maximum, so appends land last
    /// regardless of prior deletions (never trust the item count, which drifts from `order`).
    private var nextOrder: Int { (routine.items.map(\.order).max() ?? -1) + 1 }

    /// Whether the routine has at least one runnable block — a unit block whose unit still resolves.
    /// Gates the Start button (an empty or all-orphaned routine has nothing to play).
    private var hasPlayableBlock: Bool {
        routine.items.contains { $0.kind.carriesUnit && $0.hasResolvableUnit }
    }

    var body: some View {
        List {
            // The name is editable both in edit mode and on a **provisional generated session** —
            // surfaced inline (not buried behind a Save-time alert) so the session you'll keep going
            // back to can be named right on the review screen (R1b).
            if isEditing || !existsInStore {
                Section {
                    TextField("Routine name", text: $routine.name)
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                        .listRowBackground(PocketColor.background)
                } header: {
                    Text("Name")
                } footer: {
                    if !existsInStore {
                        Text("Name it to keep it in your routines and run it again.")
                            .font(.futura(.caption))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                }
            }

            Section("Blocks") {
                if routine.items.isEmpty {
                    Text(isEditing
                         ? "Empty routine. Add exercises, loops or songs, and rests between them."
                         : "Empty routine. Tap Edit to add blocks.")
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                        .listRowBackground(PocketColor.background)
                } else {
                    ForEach(Array(routine.orderedItems.enumerated()), id: \.element.uid) { pair in
                        RoutineItemRow(item: pair.element, number: pair.offset + 1)
                            .listRowBackground(PocketColor.background)
                    }
                    .onMove(perform: move)
                    .onDelete(perform: delete)
                }
            }

            if isEditing {
                Section {
                    Button {
                        addingUnit = true
                        haptic(.light)
                    } label: {
                        Label("Add exercise, loop or song", systemImage: "plus.circle.fill")
                            .font(.futura(.body))
                            .foregroundStyle(PocketColor.practice)
                    }
                    .listRowBackground(PocketColor.background)

                    Button {
                        addRest()
                    } label: {
                        Label("Insert rest", systemImage: "pause.circle")
                            .font(.futura(.body))
                            .foregroundStyle(PocketColor.textSecondary)
                    }
                    .listRowBackground(PocketColor.background)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(routine.name.isEmpty ? "Routine" : routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isEditing)
        .environment(\.editMode, .constant(isEditing ? .active : .inactive))
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) { startBar }
        .sheet(isPresented: $addingUnit) {
            // Closing the sheet from the parent (not from inside the picker) means a pick from
            // any drill-in depth dismisses cleanly — a child's own dismiss would only pop.
            AddRoutineUnitSheet(onPickExercise: { addExercise($0); addingUnit = false },
                                onPickLoop: { addLoop($0); addingUnit = false },
                                onPickSong: { addSong($0); addingUnit = false })
        }
        .fullScreenCover(item: $playingRoutine) { RoutinePlayerView(routine: $0) }
    }

    /// The bottom **Start** button that launches the player — the primary action once a routine is
    /// built (ADR 0066/0071). Shown only in read-only mode (editing has Save/Cancel instead) and only
    /// when there's something runnable. Pinned to the bottom via `safeAreaInset` so it floats over the
    /// block list; every routine detail screen carries it.
    @ViewBuilder
    private var startBar: some View {
        if !isEditing && hasPlayableBlock {
            Button(action: startPlaying) {
                Label("Start", systemImage: "play.fill")
                    .font(.futura(.body, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(PocketColor.practice, in: Capsule())
                    .foregroundStyle(PocketColor.background)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .accessibilityLabel("Start routine")
        }
    }

    /// Start the session in the player. A **provisional** generated session is committed first
    /// (Start is a deliberate keep, and running must write real practice history), then resolved into
    /// the main context so its run screens write to the real store — not this view's editing sandbox.
    private func startPlaying() {
        if !existsInStore { commitProvisional(named: routine.name) }
        playingRoutine = appContext.model(for: routine.persistentModelID) as? Routine
        haptic(.medium)
    }

    /// Commit a provisional generated session to the library under `name` (the inline Name field),
    /// de-duplicated against the existing routines, and flip it into a normal stored routine. If the
    /// field was blanked, fall back to a fresh dated default rather than saving an unnamed session.
    /// Idempotent — a no-op once already stored.
    private func commitProvisional(named name: String) {
        guard !existsInStore else { return }
        let others = ((try? editContext.fetch(FetchDescriptor<Routine>())) ?? [])
            .filter { $0.persistentModelID != routine.persistentModelID }
            .map(\.name)
        let requested = name.trimmingCharacters(in: .whitespaces)
        let base = requested.isEmpty
            ? QuickSessionNaming.defaultName(existing: others, date: .now)
            : requested
        routine.name = QuickSessionNaming.uniqued(base, existing: others)
        try? editContext.save()
        existsInStore = true
        isEditing = false
        haptic(.medium)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if isEditing {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { cancelEdits() }
                    .tint(PocketColor.textSecondary)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { saveEdits() }
                    .font(.futura(.body, weight: .bold))
                    .tint(PocketColor.practice)
            }
        } else if !existsInStore {
            // A provisional generated session: the primary action is an explicit Save, not Edit —
            // nothing is in the library until the user commits it. The name is edited inline in the
            // Name section above (R1b), so Save commits the current name directly.
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") { commitProvisional(named: routine.name) }
                    .font(.futura(.body, weight: .bold))
                    .tint(PocketColor.practice)
            }
        } else {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { isEditing = true; haptic(.light) }
                    .tint(PocketColor.practice)
            }
        }
    }

    // MARK: - Commit / discard

    /// Commit the sandbox and drop back to the read-only view. A brand-new routine with nothing in it
    /// is dismissed rather than saved (an abandoned "New routine" leaves no empty shell).
    private func saveEdits() {
        if !existsInStore && routine.items.isEmpty
            && routine.name.trimmingCharacters(in: .whitespaces).isEmpty {
            dismiss()
            return
        }
        try? editContext.save()
        existsInStore = true
        isEditing = false
        haptic(.medium)
    }

    /// Discard in-flight edits. A new routine has nothing to return to, so it dismisses; an existing
    /// one rebuilds a clean sandbox from the store and returns to the read-only view.
    private func cancelEdits() {
        guard existsInStore else { dismiss(); return }
        let context = ModelContext(container)
        context.autosaveEnabled = false
        if let local = context.model(for: routine.persistentModelID) as? Routine {
            routine = local
        }
        editContext = context
        isEditing = false
        haptic(.light)
    }

    // MARK: - Mutations (sandbox only — provisional until Save)

    /// Add a picked exercise as a block. The picker hands back the unit from the app's main
    /// context, so it's re-resolved into the sandbox by id before it's referenced (never mix
    /// objects across contexts).
    private func addExercise(_ picked: Exercise) {
        guard let local = editContext.model(for: picked.persistentModelID) as? Exercise else {
            return
        }
        insert(.item(local, order: nextOrder))
    }

    private func addLoop(_ picked: Loop) {
        guard let local = editContext.model(for: picked.persistentModelID) as? Loop else { return }
        insert(.item(local, order: nextOrder))
    }

    private func addSong(_ picked: Song) {
        guard let local = editContext.model(for: picked.persistentModelID) as? Song else { return }
        insert(.item(local, order: nextOrder))
    }

    private func addRest() {
        insert(.rest(order: nextOrder))
        haptic(.light)
    }

    private func insert(_ item: RoutineItem) {
        item.routine = routine
        editContext.insert(item)
        haptic(.medium)
    }

    /// Drag-reorder writes the explicit `order` (ADR 0066 R2) so play order survives a fetch.
    private func move(from offsets: IndexSet, to destination: Int) {
        var ordered = routine.orderedItems
        ordered.move(fromOffsets: offsets, toOffset: destination)
        for (index, item) in ordered.enumerated() { item.order = index }
        haptic(.light)
    }

    /// Delete the swiped blocks (offsets index the *displayed* ordered list), then renumber
    /// the survivors so `order` stays contiguous.
    private func delete(_ offsets: IndexSet) {
        let ordered = routine.orderedItems
        for index in offsets { editContext.delete(ordered[index]) }
        for (index, item) in routine.orderedItems.enumerated() { item.order = index }
        haptic(.medium)
    }
}

#Preview("Routine detail") {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: Routine.self, RoutineItem.self, Exercise.self, Song.self, Loop.self,
        configurations: .init(isStoredInMemoryOnly: true))
    let drill = Exercise(name: "Alternating picking", currentTempo: 70, commandTempo: 96)
    container.mainContext.insert(drill)
    let routine = Routine(name: "Morning warm-up")
    routine.items = [RoutineItem.item(drill, kind: .warmup, order: 0),
                     RoutineItem.rest(order: 1),
                     RoutineItem.item(drill, order: 2)]
    container.mainContext.insert(routine)
    try? container.mainContext.save()
    return NavigationStack { RoutineDetailView(container: container, existing: routine) }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
