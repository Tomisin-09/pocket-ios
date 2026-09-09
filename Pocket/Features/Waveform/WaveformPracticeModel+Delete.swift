import SwiftUI

/// Loop / marker **deletion with undo** (ADR 0019), one row or a whole selection
/// (ADR 0125). Split out of `+Actions.swift` to keep each file under the length budget.
///
/// **Deferred, not delete-then-restore.** The original implementation snapshotted a loop's
/// scalars and rebuilt it on undo. That worked for a loop's *numbers* and quietly lost
/// everything hanging off it: `Loop` cascade-owns its journal entries and its recorded
/// takes, and nullifies the routine blocks that reference it (ADR 0066). A rebuilt loop
/// came back with an empty journal. So the delete now **hides** the row and destroys the
/// object only when the undo window closes — the same trade Slice 3 settled on for the
/// practice libraries: nothing can be lost by a missed commit, and the worst case is a
/// delete that didn't happen. Bulk delete would have made the old lossiness N times worse.
extension WaveformPracticeModel {

    // MARK: Loops

    /// Delete one loop, with an Undo toast.
    func deleteLoop(_ loop: Loop) { deleteLoops([loop]) }

    /// Delete every selected loop under a **single** toast — one action, one undo.
    func deleteSelectedLoops() {
        deleteLoops(selectedLoops)
        loopSelection.reconcile(with: loops.map(\.uid))
    }

    private func deleteLoops(_ targets: [Loop]) {
        guard !targets.isEmpty else { return }
        let uids = Set(targets.map(\.uid))
        let wasActive = activeLoopID.map(uids.contains) ?? false
        let previouslyActive = activeLoopID
        if wasActive {
            // Clean state (ADR 0029): deleting the loop you're hearing plays through
            // the song rather than silently arming a different saved region. Cleared
            // *before* hiding it so the `activeLoopID` didSet (ADR 0040) persists this
            // loop's last-practiced speed while the loop is still in `loops`.
            activeLoopID = nil
            applyActiveLoopToEngine()
        }
        withAnimation(.easeOut(duration: 0.2)) { pendingDeletedLoopUIDs.formUnion(uids) }

        let message = targets.count == 1
            ? "Deleted \(targets[0].name)"
            : "Deleted \(targets.count) loops"
        presentUndo(message) { [weak self] in
            guard let self else { return }
            withAnimation(.easeOut(duration: 0.2)) { self.pendingDeletedLoopUIDs.subtract(uids) }
            if wasActive {
                self.activeLoopID = previouslyActive
                self.applyActiveLoopToEngine()
            }
        } commit: { [weak self] in
            guard let self else { return }
            for loop in self.song.loops where uids.contains(loop.uid) { self.context.delete(loop) }
            self.pendingDeletedLoopUIDs.subtract(uids)
        }
    }

    // MARK: Markers

    /// Delete one marker, with an Undo toast.
    func deleteMarker(_ marker: Marker) { deleteMarkers([marker]) }

    /// Delete every selected marker under a single toast.
    func deleteSelectedMarkers() {
        deleteMarkers(selectedMarkers)
        markerSelection.reconcile(with: markers.map(\.uid))
    }

    private func deleteMarkers(_ targets: [Marker]) {
        guard !targets.isEmpty else { return }
        let uids = Set(targets.map(\.uid))
        withAnimation(.easeOut(duration: 0.2)) { pendingDeletedMarkerUIDs.formUnion(uids) }

        let message = targets.count == 1
            ? "Deleted \(targets[0].label)"
            : "Deleted \(targets.count) markers"
        presentUndo(message) { [weak self] in
            guard let self else { return }
            withAnimation(.easeOut(duration: 0.2)) { self.pendingDeletedMarkerUIDs.subtract(uids) }
        } commit: { [weak self] in
            guard let self else { return }
            for marker in self.song.markers where uids.contains(marker.uid) { self.context.delete(marker) }
            self.pendingDeletedMarkerUIDs.subtract(uids)
        }
    }
}
