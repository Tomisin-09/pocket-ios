import SwiftData
import SwiftUI

/// The routine screen's half of **temporary sessions** (ADR 0243). Split out of `RoutineDetailView`,
/// which sits near the 400-line cap.
///
/// A routine on this screen is in one of three states, where there used to be two:
///
/// | state | `existsInStore` | `routine.isTemporary` | toolbar |
/// |---|---|---|---|
/// | provisional (on review, nothing written) | false | false | Save |
/// | temporary (started, not saved) | true | true | Save |
/// | saved | true | false | Edit |
///
/// `existsInStore` still means *in the store*: it decides whether a change writes straight through.
/// `isSaved` means *in Routines*, and it gates everything a player would put into a routine (D5).
extension RoutineDetailView {

    /// What **Start** does with a provisional session (D1). The line falls between builders.
    enum ProvisionalStart {
        /// Today's session and Quick session (`PracticePlanner`). Start puts it in the store as a
        /// temporary session, which reaches Routines only if it is saved.
        case temporary
        /// A song's routine, a Collection's session, *Put it together*. Start keeps it, as Save does.
        case saved
    }

    /// Whether this routine is in Routines: in the store, and not a temporary session.
    ///
    /// The gate for a reminder (0186), a reference (0167) and a share (0236) (D5). Each is something a
    /// player would put into the routine, and the next planner Start would delete it along with a
    /// temporary session. Edit is gated by the toolbar, which offers **Save** in its place. A
    /// temporary session's **history** is still shown, on `existsInStore`: it has been run, and
    /// "practised once, today" is what the saved routine will carry.
    var isSaved: Bool { existsInStore && !routine.isTemporary }

    /// Start, on a provisional **planner** session (D1–D3): put it in the store as temporary, and
    /// delete every other temporary session, **in the same save, through this screen's sandbox**.
    ///
    /// The sandbox is the context that made this session's blocks, so it is the one whose view of
    /// each drill and loop includes them. Deleting the old session anywhere else unlinks the blocks
    /// the two share — `Routine.deleteTemporaries` has the case. One save also means there is never a
    /// moment with two.
    ///
    /// The name is the one on the review screen, or the dated default if it was blanked. It is not
    /// de-duplicated until the session is saved (D4).
    func commitTemporary() {
        guard !existsInStore else { return }
        trimDescription()
        let savedNames = Routine.saved((try? editContext.fetch(FetchDescriptor<Routine>())) ?? [])
            .filter { $0.persistentModelID != routine.persistentModelID }
            .map(\.name)
        routine.name = QuickSessionNaming.temporaryName(requested: routine.name, existing: savedNames,
                                                        date: .now)
        routine.isTemporary = true
        Routine.deleteTemporaries(replacedBy: routine.uid, in: editContext)
        try? editContext.save()
        existsInStore = true
        isEditing = false
    }

    /// **Save**, on a temporary session's own screen (D4, "any time later"). Written through the
    /// sandbox, which holds no other change: a temporary session can't enter edit mode.
    func saveTemporarySession() {
        routine.saveTemporary(in: editContext)
        haptic(.medium)
    }

    /// The player is closing. If this is a temporary session, read it again from the store.
    ///
    /// *Save as a routine* on the finish screen writes the **main** context. This screen holds its own
    /// sandbox, which doesn't see that write, so without this it would go on offering **Save** for a
    /// routine that is already in Routines. A saved routine has nothing to re-read here.
    func rereadAfterPlaying() {
        guard existsInStore, routine.isTemporary else { return }
        rebuildSandbox()
    }
}
