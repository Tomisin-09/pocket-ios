import SwiftData
import SwiftUI

/// Presents the reference-link editor, and owns the write that follows it (ADR 0167).
///
/// **This exists because the obvious placement does not work.** `ReferencesSection` originally kept
/// the `ReferenceLinkDraft` in `@State` and attached its own `.sheet` to the `Section` — everything
/// in one component, which is the shape you would reach for. Measured 2026-08-17 on
/// `ExerciseDetailSheet`: tapping **Add a link** dismissed the *detail sheet* and left the app on
/// the exercise run screen. The editor never appeared. Nothing failed to build, no assertion in the
/// app objected, and the only evidence was the accessibility hierarchy captured at the moment of the
/// tap — three earlier attempts at that shot blamed the selector instead, one six-minute run each.
///
/// A sheet presented from a row or section *inside* another sheet's `Form` is competing with the
/// presentation that already owns that screen. `ExerciseDetailSheet` had the working pattern in it
/// the whole time: its song picker hangs off the `NavigationStack`, not off the row that opens it.
/// So the host holds the state and attaches this; the section only raises the intent.
///
/// Attach it to the host's **root** — the `NavigationStack` or the `List` — never inside the `Form`:
///
/// ```swift
/// NavigationStack { Form { … ReferencesSection(owner: exercise, accent: …, editing: $editingRef) } }
///     .referenceLinkEditing($editingRef, owner: exercise, accent: PocketColor.practice)
/// ```
struct ReferenceLinkEditing<Owner: ReferenceLinkOwner & AnyObject>: ViewModifier {
    @Binding var editing: ReferenceLinkDraft?
    let owner: Owner
    let accent: Color
    /// See `ReferencesSection.context` — `RoutineDetailView` must pass its sandbox, or the insert
    /// lands in a different context from the routine it points at.
    var context: ModelContext?
    /// See `ReferencesSection.savesImmediately` — false only in the routine editor, whose contract
    /// is that Cancel discards and Save keeps.
    var savesImmediately: Bool = true

    @Environment(\.modelContext) private var environmentContext

    private var writeContext: ModelContext { context ?? environmentContext }

    func body(content: Content) -> some View {
        content.sheet(item: $editing) { draft in
            ReferenceLinkEditor(draft: draft, accent: accent) { title, url in
                commit(draft, title: title, url: url)
            }
        }
    }

    /// The write. Lives here rather than in the section because the section no longer knows when a
    /// save happened — the editor reports back to whoever presented it.
    private func commit(_ draft: ReferenceLinkDraft, title: String, url: String) {
        switch draft {
        case .adding:
            ReferenceLinkStore.add(title: title, url: url, to: owner, in: writeContext)
        case .editing(let link):
            ReferenceLinkStore.update(link, title: title, url: url)
        }
        guard savesImmediately else { return }
        try? writeContext.save()
    }
}

extension View {
    /// Host the reference-link editor for `owner`. Attach at the screen's root — see
    /// `ReferenceLinkEditing` for the failure that rule comes from.
    func referenceLinkEditing<Owner: ReferenceLinkOwner & AnyObject>(
        _ editing: Binding<ReferenceLinkDraft?>,
        owner: Owner,
        accent: Color,
        context: ModelContext? = nil,
        savesImmediately: Bool = true
    ) -> some View {
        modifier(ReferenceLinkEditing(editing: editing, owner: owner, accent: accent,
                                      context: context, savesImmediately: savesImmediately))
    }
}
