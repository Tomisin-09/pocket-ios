import SwiftUI

/// The routine's **Where you learned it** section (ADR 0167), split out of `RoutineDetailView` to
/// keep that file under the 400-line cap.
///
/// It is one `if` in the body and three paragraphs of reasoning, because this surface is the odd one
/// out among the five that host a References section — and every way it differs is a correctness
/// point rather than a preference.
extension RoutineDetailView {

    /// Where this session came from — a course's week 3, a teacher's assignment.
    ///
    /// The routine is the **most on-thesis owner** of the four (`docs/positioning.md` §1: a course
    /// belongs to a sitting, not to a single drill). It sits directly under the **Description**
    /// (ADR 0177), which closed the gap this note used to name: where you learned it and what it is
    /// for are neighbours on the screen and separate fields in the model.
    ///
    /// Three constraints, none of which the other four surfaces need:
    ///
    /// 1. **Held back until the routine is in the store.** A provisional generated session is not
    ///    saved yet, and attaching a link would insert it through the relationship — quietly keeping
    ///    a routine the player never chose to keep.
    /// 2. **Writes into `editContext`, not the environment's context.** `routine` is faulted into
    ///    this screen's private child context; inserting a link through the app context while
    ///    pointing it at that routine is a cross-context relationship, which is a corruption rather
    ///    than a preference.
    /// 3. **Read-only outside edit mode, and no per-change save inside it.** Outside edit mode there
    ///    is no Save, so a link added there would sit in the sandbox until the next Cancel discarded
    ///    it. Inside, saving on each change would commit whatever block rearrangement was pending —
    ///    an unrelated edit made permanent because somebody added a link. So links follow the
    ///    contract the blocks already follow, and the one the manual already states for this screen:
    ///    **Cancel discards, Save keeps.**
    @ViewBuilder var referencesSection: some View {
        if existsInStore {
            if isEditing {
                ReferencesSection(owner: routine, accent: PocketColor.practice,
                                  context: editContext, savesImmediately: false,
                                  editing: $editingReference)
            } else {
                ReferencesReadOnlySection(owner: routine, accent: PocketColor.practice)
            }
        }
    }
}
