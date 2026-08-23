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
    /// write to the real store, not this view's private editing sandbox. Internal so the
    /// block-preview extension (`RoutineDetailView+BlockPreview`) can resolve a tapped unit into it.
    @Environment(\.modelContext) var appContext

    /// The shared store — kept so Cancel can rebuild a clean sandbox that drops in-flight edits.
    private let container: ModelContainer
    /// Private editing scope over the shared store — never autosaves, so nothing persists until
    /// `saveEdits()` calls `save()` on it explicitly. Internal so the same-type extensions in
    /// `+Units` / `+Rests` can insert into it.
    @State var editContext: ModelContext
    /// The routine under edit, resolved into (or created in) `editContext`. Internal (not private) so
    /// the length-readout extension (`RoutineDetailView+Length`) can read it.
    @State var routine: Routine
    /// Whether this routine has been committed to the store yet — drives Cancel (discard vs dismiss)
    /// and the empty-new drop on Save. Flips true after the first Save of a new routine. Internal for
    /// the length-readout extension.
    @State var existsInStore: Bool
    /// Read-only by default; every mutating control is revealed only in edit mode. A brand-new
    /// routine opens directly in edit mode (there's nothing to view yet).
    @State var isEditing: Bool
    /// Raised when a swipe tries to mark a block for recording and the microphone is off (ADR 0180).
    @State var micAccessBlocked = false

    /// Entitlement (ADR 0112) — internal so the access extension reads it. Routines are Pro; the
    /// curated free-taste routine opens as a rearrange-only demo.
    @Environment(\.isPro) var isPro

    @State private var addingUnit = false
    /// What the open picker has added, keyed by `RoutineUnitPick.pickID` → the `RoutineItem.uid` it
    /// created (ADR 0127). The editor owns this, not the picker: it drives the picker's checkmarks
    /// *and* finds the exact block to remove on a second tap, so the two can't disagree. Cleared
    /// when the sheet closes — it describes one picking session, never the routine's contents.
    @State var addedPickIDs: [String: UUID] = [:]
    /// Whether the block list is in **rest-insert mode** (ADR 0127) — entered by holding *Insert
    /// rest*, it replaces the list with tappable gaps between the blocks. Internal so the block-row
    /// and rest extensions can read it.
    @State var insertingRests = false
    /// The gap slot whose "rest already here" popover is showing, or `nil`. `restSlotCount` is the
    /// append row's own slot, so the same guard explains itself on both paths.
    @State var restGuardSlot: Int?
    /// The routine to run, resolved into the main context — drives the full-screen player. `nil`
    /// when not playing.
    @State private var playingRoutine: Routine?
    /// The block being previewed (ADR 0071 R4b) — tapping an exercise/loop block in read-only mode
    /// pushes a read-only preview (content · tempo · staircase · audio audition). Resolved into the app
    /// context, so any drill-down edits write to the real store, not this view's sandbox. `nil` = none.
    @State var previewTarget: RoutineBlockPreviewTarget?
    /// The block whose **reps** are being edited (ADR 0076) — set by tapping a unit block in edit
    /// mode, presenting the `BlockRepsEditor` sheet. The item lives in the editing sandbox, so its
    /// change is provisional until Save. Internal so the block-row extension can set it. Held as a
    /// `uid`-keyed `StableRef`, not the raw `RoutineItem`: an item in a just-generated or unsaved
    /// routine has a temporary `persistentModelID` that flips on the first save, which would dismiss
    /// the reps editor mid-edit if keyed on it (ADR 0090 / swiftdata-gotchas).
    @State var repsEditorItem: StableRef<RoutineItem>?
    /// The reference link being added or edited (ADR 0167). Internal so the `+References` extension
    /// binds it. Held here because a sheet presented from inside the `List` does not present — see
    /// `ReferenceLinkEditing`.
    @State var editingReference: ReferenceLinkDraft?

    /// The session length the user asked the planner for, in minutes — set only on a provisional
    /// generated session so the review screen can show its estimate against a soft budget (R3).
    /// `nil` for a normal routine (no target to compare against). Internal for the length extension.
    let targetMinutes: Int?

    /// Build the sandbox. An existing routine is faulted into the child context by its id (opens
    /// read-only); a nil `existing` means a fresh routine created only in the sandbox, opened in edit
    /// mode and persisted iff you Save.
    init(container: ModelContainer, existing: Routine?) {
        self.container = container
        self.targetMinutes = nil
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
    init(container: ModelContainer, generatedSession blocks: [SessionBlock], defaultName: String,
         targetMinutes: Int? = nil) {
        self.container = container
        self.targetMinutes = targetMinutes
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
    var nextOrder: Int { (routine.items.map(\.order).max() ?? -1) + 1 }

    /// Whether the routine has at least one runnable block — a unit block whose unit still resolves.
    /// Gates the Start button (an empty or all-orphaned routine has nothing to play). Internal for
    /// the length-readout extension.
    var hasPlayableBlock: Bool {
        routine.items.contains { $0.kind.carriesUnit && $0.hasResolvableUnit }
    }

    // `canAddBlocks` / `canDeleteBlocks` live in `RoutineDetailView+Access` (ADR 0112). A
    // provisional generated session (`!existsInStore`) stays editable without an Edit tap — it's a
    // *template* the player customises (e.g. adding a drill from outside the source collection,
    // ADR 0118) before the single Save commits it — while drag-reorder needs edit mode on a stored
    // routine.

    var body: some View {
        List {
            // The routine's own words — its name and what the session is for (ADR 0177). Both live
            // in `RoutineDetailView+Prose.swift` and share one edit gate: edit mode, or a
            // provisional generated session, which is named and described inline on the review
            // screen rather than behind a Save-time alert (R1b).
            nameSection
            descriptionSection

            Section {
                if routine.items.isEmpty {
                    Text(canAddBlocks
                         ? "Empty routine. Add exercises, loops or songs, and rests between them."
                         : "Empty routine. Tap Edit to add blocks.")
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                        .listRowBackground(PocketColor.background)
                } else if insertingRests {
                    // Rest-insert mode interleaves gap rows between the blocks, so it can't share
                    // the plain ForEach: `onMove`/`onDelete` offsets index the rows, and every
                    // other row here is a gap. Reordering is off for the duration.
                    restInsertRows
                } else {
                    ForEach(Array(routine.orderedItems.enumerated()), id: \.element.uid) { pair in
                        blockRow(pair.element, number: pair.offset + 1)
                            .listRowBackground(PocketColor.background)
                            .swipeActions(edge: .leading) { recordSwipe(for: pair.element) }
                    }
                    .onMove(perform: blockMoveAction)
                    .onDelete(perform: blockDeleteAction)
                }
            } header: {
                Text(insertingRests ? "Tap where a rest goes" : "Blocks")
            }

            // How long it is, when you last did it, how many times (ADR 0173). Lives in
            // `RoutineDetailView+History.swift` — one section rather than two because the old
            // length gate and a history gate were near-complements, so the screen would have
            // shown one or the other and never both.
            lengthAndHistorySection

            // Where this session came from (ADR 0167). Lives in
            // `RoutineDetailView+References.swift` — the sandbox makes this surface the odd
            // one out among the five that host a section, in three ways written up there.
            referencesSection

            if canAddBlocks {
                Section {
                    if insertingRests {
                        doneInsertingRestsRow
                    } else {
                        Button {
                            addingUnit = true
                            haptic(.light)
                        } label: {
                            Label("Add exercise, loop or song", systemImage: "plus.circle.fill")
                                .font(.futura(.body))
                                .foregroundStyle(PocketColor.practice)
                        }
                        .listRowBackground(PocketColor.background)

                        insertRestRow
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(routine.name.isEmpty ? "Routine" : routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(isEditing)
        // Rest-insert mode borrows the list: drag handles and swipe-delete would fight the gap
        // taps, so edit mode is suspended (not exited) for its duration.
        .environment(\.editMode, .constant(isEditing && !insertingRests ? .active : .inactive))
        .modifier(MicAccessAlert(isPresented: $micAccessBlocked))
        .toolbar { toolbarContent }
        .safeAreaInset(edge: .bottom) { startBar }
        // The picker no longer dismisses on a pick (ADR 0127) — it adds and stays open, so the
        // session's adds are tracked here and forgotten when it closes.
        .sheet(isPresented: $addingUnit, onDismiss: { addedPickIDs.removeAll() },
               content: { AddRoutineUnitSheet(addedIDs: Set(addedPickIDs.keys),
                                              onToggle: toggleUnit) })
        .fullScreenCover(item: $playingRoutine) { RoutinePlayerView(routine: $0) }
        .sheet(item: $repsEditorItem) { repsEditorSheet($0.value) }
        // Attached to the `List`, never inside it — see `ReferenceLinkEditing`. Writes into the
        // sandbox and defers the save, so links follow this screen's Cancel/Save contract.
        .referenceLinkEditing($editingReference, owner: routine, accent: PocketColor.practice,
                              context: editContext, savesImmediately: false)
        .navigationDestination(item: $previewTarget) { blockPreview($0) }
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
        trimDescription()
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
        // A generated session being *kept* is the moment a routine exists (ADR 0120). Not the
        // `context.insert` in `init` — that fires into the sandbox for every "New routine" tap,
        // including the ones abandoned without saving.
        Analytics.send(.routineCreated(items: routine.items.count, generated: true))
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
    ///
    /// "Nothing in it" counts the **description** too (ADR 0177): typing what a session is for and
    /// nothing else is thin, but it is something the player wrote, and dropping it on Save would be
    /// the screen discarding work without saying so.
    private func saveEdits() {
        trimDescription()
        if !existsInStore && routine.items.isEmpty && routine.notes.isEmpty
            && routine.name.trimmingCharacters(in: .whitespaces).isEmpty {
            dismiss()
            return
        }
        let isNew = !existsInStore
        try? editContext.save()
        existsInStore = true
        if isNew {
            Analytics.send(.routineCreated(items: routine.items.count, generated: false))
        }
        isEditing = false
        insertingRests = false
        haptic(.medium)
    }

    /// Discard in-flight edits. A new routine has nothing to return to, so it dismisses; an existing
    /// one rebuilds a clean sandbox from the store and returns to the read-only view.
    private func cancelEdits() {
        // Leaving edit mode must leave rest-insert mode with it — the gap rows are an editing
        // affordance, and their only way out is hidden once the add section goes.
        insertingRests = false
        restGuardSlot = nil
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
    //
    // The unit-adders live in `RoutineDetailView+Units.swift` and the rest-insert mode in
    // `+Rests.swift`, keeping this file under the 400-line cap; both reach `insert`/`nextOrder`
    // here, which is why those are internal rather than private.

    func insert(_ item: RoutineItem) {
        item.routine = routine
        editContext.insert(item)
        haptic(.medium)
    }

    /// Renumber the blocks so `order` stays contiguous after an insert or a delete. The play order
    /// is the explicit `order` (ADR 0066 R2), so every structural change re-lays it.
    func renumberBlocks() {
        for (index, item) in routine.orderedItems.enumerated() { item.order = index }
    }

}
