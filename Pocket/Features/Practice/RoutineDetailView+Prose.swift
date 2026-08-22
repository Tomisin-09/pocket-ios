import SwiftUI

/// The routine's **own words** — its name and its description (ADR 0177) — split out of
/// `RoutineDetailView`, which sits at the 400-line cap.
///
/// The two live together because they answer the same question at different lengths: *what is this
/// session?* The name is what you pick it by in a list; the description is what you cannot fit in a
/// name — who it is for, which week of the course it covers, why it is ordered the way it is. Every
/// other practice unit has had both since it shipped (`Exercise.name`/`.notes`,
/// `Song.title`/`.comment`); the routine — the container a teacher actually hands over — had only
/// the name.
extension RoutineDetailView {

    /// Whether this screen's prose fields are editable.
    ///
    /// The same condition the name has always used: **edit mode, or a provisional generated
    /// session**. A generated session is a template the player is customising before the single Save
    /// commits it, so making them read the blocks in one pass and then tap Edit to say what the
    /// session is for would be a gate around nothing.
    var canEditProse: Bool { isEditing || !existsInStore }

    /// The name, editable inline (R1b) — moved here verbatim from `RoutineDetailView.body`.
    @ViewBuilder var nameSection: some View {
        if canEditProse {
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
    }

    /// What the session is for.
    ///
    /// **It binds straight to the sandbox, with no `@State` draft.** `ExerciseDetailSheet` stages its
    /// notes in local state and commits them on Done because it edits the live store and has no other
    /// way to be cancellable. This screen already has one: `routine` is faulted into a private
    /// context with autosave off, so typing here is provisional by construction and follows the
    /// contract the blocks, the name and the links all follow — **Cancel discards, Save keeps**. A
    /// second draft layer on top of a sandbox would be two undo stories for one field.
    ///
    /// **It is not gated on `existsInStore`, and that is the one way it differs from the links
    /// beside it.** A `ReferenceLink` is a separate model, so attaching one to a provisional session
    /// inserts a row through a relationship and quietly keeps a routine the player never chose to
    /// keep. A description is a `String` on the routine itself: it cannot persist anything the
    /// routine's own Save does not.
    ///
    /// **Read-only and empty shows nothing at all.** The alternative — a permanent "No description"
    /// row on every routine that has never had one — is clutter on the many to advertise a field to
    /// the few, and it is written in the register the brief rules out (design-brief §3.5): a
    /// standing note about a thing you have not done. The field is found where every other change to
    /// a routine is found, behind **Edit**.
    @ViewBuilder var descriptionSection: some View {
        if canEditProse {
            Section {
                TextField("What this session is for, who it's for, what to watch…",
                          text: $routine.notes, axis: .vertical)
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
                    .lineLimit(3...8)
                    .keyboardDoneButton()
                    .accessibilityIdentifier(UITestHooks.routineDescriptionField)
                    .listRowBackground(PocketColor.background)
            } header: {
                Text("Description")
            } footer: {
                Text("A note to yourself about the session — saved with the routine.")
                    .font(.futura(.caption))
                    .foregroundStyle(PocketColor.textSecondary)
            }
        } else if !routine.notes.isEmpty {
            Section {
                Text(routine.notes)
                    .font(.futura(.body))
                    .foregroundStyle(PocketColor.textPrimary)
                    .listRowBackground(PocketColor.background)
            } header: {
                Text("Description")
            }
        }
    }

    /// Tidy the description at the moment it is committed.
    ///
    /// Trimming on **write** rather than on read, so the stored value is the value every reader
    /// sees — including the `!routine.notes.isEmpty` test above, which a description of one stray
    /// newline would otherwise pass, drawing an empty section on the read-only screen. `notes` is a
    /// vertical `TextField`, so a trailing newline is the likely case, not an exotic one.
    ///
    /// The **name is deliberately left alone**: it is committed through two different paths with
    /// their own trimming and de-duplication (`commitProvisional` → `QuickSessionNaming`), and
    /// quietly rewriting a stored routine's name is a behaviour change this feature has no business
    /// making. `RoutinePresets.slug(forName:)` matches names exactly.
    func trimDescription() {
        routine.notes = routine.notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
