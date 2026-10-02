import Foundation
import SwiftData

/// **Temporary sessions** (ADR 0243): the rules every surface reads, kept in one place.
///
/// Today's session and a Quick session go into the store when they start, because the player
/// resolves them from the main context and the run screens stamp them. They reach Routines only if
/// the player saves one. So *in the store* no longer means *in Routines*, and each surface has to say
/// which it means. A surface about **what you keep** lists `saved(_:)`. A surface about **what you
/// practised** (Jump back in, the Recent routines rail, a session note's link) lists every routine,
/// as it always has (D2).
extension Routine {

    /// The routines a surface about what you keep shows (D2): the Routines library with its search,
    /// sort, favourites and folders, the count on Practice, Add to routine, the archive, and the names
    /// a new routine is de-duplicated against.
    ///
    /// Filtered in memory and never in a `#Predicate`, the way the library's favourites filter
    /// already works.
    static func saved(_ routines: [Routine]) -> [Routine] {
        routines.filter { !$0.isTemporary }
    }

    /// The temporary sessions that starting the one with `uid` replaces (D3): **every other** one,
    /// not only the last. So there is never more than one, and a stray left by a crash between the
    /// two writes is cleared by the next Start.
    static func temporariesReplaced(by uid: UUID, in routines: [Routine]) -> [Routine] {
        routines.filter { $0.isTemporary && $0.uid != uid }
    }

    /// Delete every temporary session but the one with `uid`, in `context` (D3). **It does not save**:
    /// the caller saves, and `context` must be the one that inserted the new session, so the two land
    /// in one save.
    ///
    /// **Never through another context.** Built first with the delete in the main context, after the
    /// review screen's sandbox had saved the new session, it unlinked every block the new session
    /// shared with the one it replaced. On the simulator the replacement's drills and loops read
    /// *Unit removed* the moment it started, while the one block the two didn't share survived. The
    /// sandbox inserted those blocks, so its view of each unit's `routineItems` holds them, and the
    /// main context's does not.
    ///
    /// Deleting cascades to the blocks and nothing else. The runs keep their loose `routineUID`, the
    /// session note keeps its words and the routine name it took a copy of, and the takes belong to
    /// their loops and exercises (ADR 0117, 0143).
    static func deleteTemporaries(replacedBy uid: UUID, in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<Routine>())) ?? []
        for routine in temporariesReplaced(by: uid, in: all) { context.delete(routine) }
    }

    /// Save this temporary session to Routines (D4, D6), in `context`.
    ///
    /// It flips the flag and gives the session a name no saved routine has, and changes nothing else.
    /// The `uid` is the one every run and the session note were written with, so the saved routine
    /// arrives with its practised count, its last-practised date and the note's link already right.
    func saveTemporary(in context: ModelContext, now: Date = .now) {
        guard isTemporary else { return }
        let others = Routine.saved((try? context.fetch(FetchDescriptor<Routine>())) ?? [])
            .filter { $0.uid != uid }
            .map(\.name)
        name = QuickSessionNaming.savedName(requested: name, existing: others, date: now)
        isTemporary = false
        try? context.save()
    }
}
