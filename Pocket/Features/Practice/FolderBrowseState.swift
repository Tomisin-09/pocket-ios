import SwiftData
import SwiftUI

/// Where a practice library is currently standing in the folder tree, and the three prompts that
/// change it (ADR 0210 D5/D10).
///
/// Owned by the library view as `@State`, so the walk is per-screen and not persisted: a folder is a
/// **place you stand**, and a library that reopened three levels down would look empty for reasons
/// the player could not see. The Exercises and Routines libraries each keep their own, over one
/// shared namespace (D3).
@Observable
final class FolderBrowseState {

    /// The prefix being browsed. `""` is the root — which is exactly today's library, because a
    /// level shows everything at or below it (D6b).
    var path = ""

    /// Whether the New-folder prompt is up.
    var creating = false

    /// The folder being renamed, if any.
    var renaming: String?

    /// The folder awaiting a delete confirmation, if any.
    var deleting: String?

    /// The text field's contents, shared by both prompts (only one is ever up).
    var draftName = ""

    /// Walk into a folder.
    func open(_ folder: String) {
        path = FolderPath.canonical(folder)
    }

    /// The trail back to the root, root first. The root's own crumb is labelled by the library, so
    /// the bar reads "Exercises › Beginner › Warm-ups".
    func crumbs(root: String) -> [FolderCrumb] {
        var trail = [FolderCrumb(name: root, path: "")]
        for prefix in FolderPath.ancestry(path) {
            trail.append(FolderCrumb(name: FolderPath.leaf(prefix), path: prefix))
        }
        return trail
    }

    /// Start a rename, pre-filling the field with the name the folder already has — renaming is far
    /// more often a correction than a replacement.
    func beginRename(of folder: String) {
        draftName = FolderPath.leaf(folder)
        renaming = folder
    }

    /// Start a create, with an empty field.
    func beginCreate() {
        draftName = ""
        creating = true
    }
}

/// One step of the breadcrumb: what to draw, and where tapping it goes.
struct FolderCrumb: Identifiable, Hashable {
    var name: String
    var path: String
    var id: String { path }
}

extension View {
    /// Hang the folder prompts — New folder, Rename, and the delete confirmation — on a library.
    ///
    /// One modifier for both libraries because all three verbs act on the **shared** namespace: a
    /// folder renamed from the Exercises library is renamed for routines too, and doing it twice in
    /// two screens is how the two would drift.
    func folderBrowsing(_ state: FolderBrowseState) -> some View {
        modifier(FolderBrowsingModifier(state: state))
    }
}

/// The prompts, and the writes behind them. Every write goes through `PracticeFolderStore`, which
/// owns the pass across exercises, routines and markers.
private struct FolderBrowsingModifier: ViewModifier {
    @Environment(\.modelContext) private var context
    @Bindable var state: FolderBrowseState

    func body(content: Content) -> some View {
        content
            .alert("New folder", isPresented: $state.creating) {
                TextField("Name", text: $state.draftName)
                Button("Cancel", role: .cancel) { state.draftName = "" }
                Button("Create", action: create)
            } message: {
                Text(state.path.isEmpty
                     ? "Made at the top level."
                     : "Made inside “\(FolderPath.leaf(state.path))”.")
            }
            .alert("Rename folder", isPresented: renamePrompt) {
                TextField("Name", text: $state.draftName)
                Button("Cancel", role: .cancel) { state.draftName = "" }
                Button("Rename", action: rename)
            } message: {
                Text("Anything filed inside it moves with it.")
            }
            .confirmationDialog(deleteTitle, isPresented: deletePrompt, titleVisibility: .visible) {
                Button("Delete folder", role: .destructive, action: delete)
                Button("Cancel", role: .cancel) {}
            } message: {
                // Said in words on purpose (D10). "Delete folder" in nearly every other app on this
                // device means something considerably more frightening than what this does.
                Text(deleteMessage)
            }
    }

    private var renamePrompt: Binding<Bool> {
        Binding(get: { state.renaming != nil }, set: { if !$0 { state.renaming = nil } })
    }

    private var deletePrompt: Binding<Bool> {
        Binding(get: { state.deleting != nil }, set: { if !$0 { state.deleting = nil } })
    }

    private var deleteTitle: String {
        "Delete “\(FolderPath.leaf(state.deleting ?? ""))”?"
    }

    /// What actually happens, counted rather than asserted — the numbers are the reassurance.
    private var deleteMessage: String {
        guard let folder = state.deleting else { return "" }
        let held = PracticeFolderStore.contents(of: folder, in: context)
        let items = [held.exercises == 1 ? "1 exercise" : "\(held.exercises) exercises",
                     held.routines == 1 ? "1 routine" : "\(held.routines) routines"]
        return "The folder goes. The \(items.joined(separator: " and ")) in it stay in your library."
    }

    private func create() {
        guard let created = PracticeFolderStore.createFolder(named: state.draftName,
                                                             at: state.path, in: context) else { return }
        Analytics.send(.folderCreated(depth: FolderPath.segments(created).count))
        state.draftName = ""
        haptic(.medium)
    }

    private func rename() {
        guard let folder = state.renaming,
              let moved = PracticeFolderStore.rename(folder, toSegment: state.draftName, in: context)
        else { return }
        // The player may be standing inside what they just renamed — follow it, rather than leaving
        // the breadcrumb pointing at a path that no longer exists and a list that reads as empty.
        if FolderPath.isUnder(state.path, prefix: folder) {
            state.path = FolderPath.renaming(folder, to: moved, in: [state.path]).first ?? ""
        }
        state.draftName = ""
        haptic(.medium)
    }

    private func delete() {
        guard let folder = state.deleting else { return }
        PracticeFolderStore.deleteFolder(folder, in: context)
        if FolderPath.isUnder(state.path, prefix: folder) {
            state.path = FolderPath.parent(folder) ?? ""
        }
        haptic(.medium)
    }
}
