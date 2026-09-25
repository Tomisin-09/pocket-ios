import SwiftData
import SwiftUI

/// What a row's **Add to routine…** asks for (ADR 0222): the unit's name, and the blocks it can
/// become — one for a drill, one per mode for a loop.
///
/// A value, not the model, so the sheet can be presented by `.sheet(item:)`: its `id` is minted
/// once per request and never changes, where a `@Model`'s `persistentModelID` can flip on a save
/// and dismiss an item-bound sheet (ADR 0090).
struct AddToRoutineRequest: Identifiable {
    let id = UUID()
    let unitName: String
    /// Never empty — the factories return `nil` rather than build a request with nothing to add.
    let choices: [AddToRoutineChoice]

    /// A drill: one choice, since an exercise block has one shape.
    static func exercise(_ exercise: Exercise, named name: String) -> AddToRoutineRequest {
        AddToRoutineRequest(unitName: name,
                            choices: [AddToRoutineChoice(pick: .exercise(exercise), label: "Exercise")])
    }

    /// A loop: a choice per mode it qualifies for, in `LoopModeAccess.modes(for:)` order — the same
    /// list its row buttons and hold menu are built from, so the sheet can't offer a block the loop
    /// can't run. `nil` when it qualifies for none — unmeasured, over audio that can't be played
    /// (ADR 0001).
    static func loop(_ loop: Loop, named name: String) -> AddToRoutineRequest? {
        let choices = LoopModeAccess.modes(for: loop).map { mode in
            AddToRoutineChoice(pick: .loop(loop, as: mode), label: mode.rowLabel)
        }
        guard !choices.isEmpty else { return nil }
        return AddToRoutineRequest(unitName: name, choices: choices)
    }
}

/// One block a unit can become — a pick, and the short word the sheet's picker shows for it.
struct AddToRoutineChoice: Identifiable {
    let pick: RoutineUnitPick
    let label: String

    var id: String { pick.pickID }
}

/// **Add to routine…** — put a drill or a loop into a routine from its own row (ADR 0222), without
/// opening the routine, pressing Edit, and walking the editor's picker back to the thing you were
/// already holding.
///
/// It mirrors the editor's picker (ADR 0127) in the one way that matters: **a tap is a toggle**. The
/// first tap appends the block as the routine's last; a second tap on the same routine takes back
/// the block *this sheet* added — never one that was there before — so a mis-tap has an obvious way
/// out, and the sheet stays open to add the same drill to a second routine.
///
/// Unlike the editor, each tap **saves**. The editor sandboxes because an edit there is many steps
/// with a Cancel at the end; here each step is one block, with its own undo in the same row. And it
/// has to reach the store, not just the main context: the routine editor opens each routine in a
/// fresh `ModelContext` that reads the store, so an unsaved append would be invisible the moment
/// you went to look at it.
struct AddToRoutineSheet: View {
    let request: AddToRoutineRequest

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var routines: [Routine]
    /// The chosen block shape's id (`AddToRoutineChoice.id`); `nil` = the first choice.
    @State private var choiceID: String?
    /// What this sheet has added: `"routineUID|pickID"` → the block's `uid`. The same session-scoped
    /// ledger the editor keeps (`addedPickIDs`), for the same reason — it finds the exact block to
    /// take back, and so can never remove one the player put there on another day.
    @State private var added: [String: UUID] = [:]
    @State private var creating = false
    @State private var draftName = ""

    private var choice: AddToRoutineChoice? {
        request.choices.first { $0.id == choiceID } ?? request.choices.first
    }

    /// A→Z, the order a reader can use — the routines library's own sort is about practice, and this
    /// is a lookup. An unnamed routine sorts under the name it is shown by.
    private var sortedRoutines: [Routine] {
        routines.sorted { displayName($0).localizedStandardCompare(displayName($1)) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                if request.choices.count > 1 {
                    Section("Add it as") {
                        Picker("Add it as", selection: Binding(get: { choice?.id ?? "" },
                                                               set: { choiceID = $0 })) {
                            ForEach(request.choices) { Text($0.label).tag($0.id) }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(PocketColor.background)
                    }
                }
                Section {
                    newRoutineButton
                    if routines.isEmpty {
                        Text("No routines yet. Make one here, with “\(request.unitName)” as its "
                             + "first block.")
                            .font(.futura(.footnote))
                            .foregroundStyle(PocketColor.textSecondary)
                            .listRowBackground(PocketColor.background)
                    } else {
                        ForEach(sortedRoutines) { routineRow($0) }
                    }
                } header: {
                    Text("Add “\(request.unitName)” to")
                } footer: {
                    if !routines.isEmpty {
                        Text("It goes in as the routine's last block. Tap a ticked routine to take "
                             + "it back out.")
                            .font(.futura(.footnote))
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(PocketColor.background.ignoresSafeArea())
            .navigationTitle("Add to routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.futura(.body, weight: added.isEmpty ? nil : .bold))
                        .tint(PocketColor.practice)
                }
            }
            .alert("New routine", isPresented: $creating) {
                TextField("Name", text: $draftName)
                Button("Cancel", role: .cancel) { draftName = "" }
                Button("Create") { createRoutine() }
                    .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            } message: {
                Text("With “\(request.unitName)” as its first block.")
            }
        }
        .presentationDetents([.large])
    }

    private var newRoutineButton: some View {
        Button {
            draftName = ""
            creating = true
        } label: {
            Label("New routine…", systemImage: "plus.rectangle.on.rectangle")
                .font(.futura(.body))
                .foregroundStyle(PocketColor.practice)
        }
        .listRowBackground(PocketColor.background)
    }

    /// One routine, as a switch — the editor picker's grammar (`AddRoutineUnitRow`): a faint
    /// `plus.circle` before, a filled check after, so the row says which way its next tap goes.
    private func routineRow(_ routine: Routine) -> some View {
        let isAdded = added[key(routine)] != nil
        let summary = detail(routine)
        return Button {
            haptic(isAdded ? .light : .medium)
            toggle(routine)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                    .font(.futura(.title3))
                    .foregroundStyle(isAdded ? PocketColor.practice
                                             : PocketColor.textSecondary.opacity(0.55))
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayName(routine))
                        .font(.futura(.body))
                        .foregroundStyle(PocketColor.textPrimary)
                    Text(summary)
                        .font(.futura(.caption))
                        .foregroundStyle(PocketColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(PocketColor.background)
        // The detail rides in the value, not lost under the label: "already in it" is exactly the
        // thing a VoiceOver user needs before deciding to add a second copy.
        .accessibilityLabel(displayName(routine))
        .accessibilityValue(isAdded ? "Added, \(summary)" : summary)
        .accessibilityHint(isAdded ? "Takes it back out of the routine" : "Adds it to the routine")
    }

    /// "4 blocks · 1 rest", plus whether the routine **already** held this block before the sheet
    /// opened. A routine may hold the same drill twice on purpose (ADR 0127), so this informs rather
    /// than refuses — but a second copy should be a choice, not an accident.
    private func detail(_ routine: Routine) -> String {
        guard let pick = choice?.pick else { return routine.blockSummary }
        let mine = added[key(routine)]
        let already = routine.items.contains { $0.uid != mine && pick.matches($0) }
        return already ? routine.blockSummary + " · already in it" : routine.blockSummary
    }

    private func displayName(_ routine: Routine) -> String {
        routine.name.isEmpty ? "Untitled routine" : routine.name
    }

    /// The ledger key: one routine **and** one block shape, so a loop added to a routine as ear
    /// training can still be added to it as a ramp — the editor's picker allows the same.
    private func key(_ routine: Routine) -> String {
        "\(routine.uid.uuidString)|\(choice?.id ?? "")"
    }

    private func toggle(_ routine: Routine) {
        if let uid = added.removeValue(forKey: key(routine)) {
            routine.removeItem(uid, in: context)
        } else {
            append(to: routine)
        }
        try? context.save()
    }

    private func append(to routine: Routine) {
        guard let pick = choice?.pick else { return }
        added[key(routine)] = routine.append(pick, in: context).uid
    }

    /// "New routine…" — made here, with this unit as its first block, so a player with no routine
    /// that fits isn't sent to the Routines library to make one and back to find the drill again.
    private func createRoutine() {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        draftName = ""
        guard !name.isEmpty else { return }
        let routine = Routine(name: name)
        context.insert(routine)
        append(to: routine)
        try? context.save()
        haptic(.medium)
    }
}
