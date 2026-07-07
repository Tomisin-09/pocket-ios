import SwiftData
import SwiftUI

/// The **routine editor** (ADR 0066, slice 2): author one `Routine` by hand — name it, add
/// exercise/loop blocks and rests, reorder them (drag writes the explicit `order`, ADR 0066
/// R2), and remove blocks. This is the *manual* half of the feature; the same `Routine`
/// model is what the V2 planner will later produce automatically.
///
/// **Edits are sandboxed.** All work happens in a private child `ModelContext` with autosave
/// off, so changes are provisional: **Save** commits them to the store; **Cancel** (or
/// leaving) discards everything — a half-built routine never lands. A brand-new routine only
/// exists in the sandbox, so an abandoned "New routine" leaves no trace.
///
/// The player (slice 3) is not wired yet, so there is no "Start" here — authoring only.
struct RoutineDetailView: View {
    @Environment(\.dismiss) private var dismiss

    /// Private editing scope over the shared store — never autosaves, so nothing persists until
    /// `save()` calls `save()` on it explicitly.
    @State private var editContext: ModelContext
    /// The routine under edit, resolved into (or created in) `editContext`.
    @State private var routine: Routine
    /// Whether this routine already existed in the store — drives the empty-new discard on Save.
    private let isExisting: Bool

    @State private var addingUnit = false

    /// Build the sandbox. An existing routine is faulted into the child context by its id; a nil
    /// `existing` means a fresh routine created only in the sandbox (persisted iff you Save).
    init(container: ModelContainer, existing: Routine?) {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        _editContext = State(initialValue: context)
        if let existing, let local = context.model(for: existing.persistentModelID) as? Routine {
            _routine = State(initialValue: local)
            isExisting = true
        } else {
            let fresh = Routine()
            context.insert(fresh)
            _routine = State(initialValue: fresh)
            isExisting = false
        }
    }

    /// The next explicit order value — one past the current maximum, so appends land last
    /// regardless of prior deletions (never trust the item count, which drifts from `order`).
    private var nextOrder: Int { (routine.items.map(\.order).max() ?? -1) + 1 }

    var body: some View {
        List {
            Section("Name") {
                TextField("Routine name", text: $routine.name)
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
                    .listRowBackground(PocketColor.background)
            }

            Section("Blocks") {
                if routine.items.isEmpty {
                    Text("Empty routine. Add exercises or loops, and rests between them.")
                        .font(.futura(.footnote))
                        .foregroundStyle(PocketColor.textSecondary)
                        .listRowBackground(PocketColor.background)
                } else {
                    ForEach(routine.orderedItems) { item in
                        RoutineItemRow(item: item)
                            .listRowBackground(PocketColor.background)
                    }
                    .onMove(perform: move)
                    .onDelete(perform: delete)
                }
            }

            Section {
                Button {
                    addingUnit = true
                    haptic(.light)
                } label: {
                    Label("Add exercise or loop", systemImage: "plus.circle.fill")
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
        .scrollContentBackground(.hidden)
        .background(PocketColor.background.ignoresSafeArea())
        .navigationTitle(routine.name.isEmpty ? "Routine" : routine.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button("Cancel") { dismiss() }
                    .tint(PocketColor.textSecondary)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if !routine.items.isEmpty { EditButton() }
                Button("Save") { save() }
                    .font(.futura(.body, weight: .bold))
                    .tint(PocketColor.practice)
            }
        }
        .sheet(isPresented: $addingUnit) {
            AddRoutineUnitSheet(onPickExercise: addExercise, onPickLoop: addLoop)
        }
    }

    // MARK: - Commit / discard

    /// Commit the sandbox to the store. A brand-new routine with nothing in it is dropped
    /// rather than saved (an abandoned "New routine" leaves no empty shell); otherwise the
    /// child context saves and its changes merge into the app's main context.
    private func save() {
        if !isExisting && routine.items.isEmpty
            && routine.name.trimmingCharacters(in: .whitespaces).isEmpty {
            dismiss()
            return
        }
        try? editContext.save()
        haptic(.medium)
        dismiss()
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

#Preview("Routine editor") {
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
