import SwiftData
import SwiftUI

/// The **routine editor** (ADR 0066, slice 2): author one `Routine` by hand — name it, add
/// exercise/loop blocks and rests, reorder them (drag writes the explicit `order`, ADR 0066
/// R2), change a block's kind, and remove blocks. This is the *manual* half of the feature;
/// the same `Routine` model is what the V2 planner will later produce automatically.
///
/// The player (slice 3) is not wired yet, so there is no "Start" here — authoring only.
struct RoutineDetailView: View {
    @Environment(\.modelContext) private var context
    @Bindable var routine: Routine

    @State private var addingUnit = false

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
                            .contextMenu { kindMenu(for: item) }
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
        .toolbar {
            if !routine.items.isEmpty {
                ToolbarItem(placement: .topBarTrailing) { EditButton() }
            }
        }
        .sheet(isPresented: $addingUnit) {
            AddRoutineUnitSheet(onPickExercise: { add(.item($0, order: nextOrder)) },
                                onPickLoop: { add(.item($0, order: nextOrder)) })
        }
    }

    // MARK: - Kind change (unit blocks only)

    /// Change a unit block's kind (Focus / Warm-up / Play). Rest blocks are authored via the
    /// dedicated "Insert rest" action, so they carry no picker.
    @ViewBuilder private func kindMenu(for item: RoutineItem) -> some View {
        if item.kind.carriesUnit {
            Picker("Block kind", selection: kindBinding(for: item)) {
                ForEach(RoutineItemKind.unitKinds) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
        }
    }

    private func kindBinding(for item: RoutineItem) -> Binding<RoutineItemKind> {
        Binding(get: { item.kind },
                set: { item.kind = $0.carriesUnit ? $0 : .focused; haptic(.light) })
    }

    // MARK: - Mutations

    /// Insert a freshly-built unit block and hang it off this routine. Setting the inverse
    /// (`routine`) is enough for SwiftData to add it to `items`; the factory already carried
    /// the appended `order`.
    private func add(_ item: RoutineItem) {
        item.routine = routine
        context.insert(item)
        haptic(.medium)
    }

    private func addRest() {
        add(.rest(order: nextOrder))
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
        for index in offsets { context.delete(ordered[index]) }
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
    return NavigationStack { RoutineDetailView(routine: routine) }
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
