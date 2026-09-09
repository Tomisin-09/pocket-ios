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

// MARK: - Snags

extension WaveformPracticeModel {

    /// Delete every selected snag under a single toast (ADR 0206 D3).
    ///
    /// **A set of marks gets an undo; one mark still does not.** ADR 0202 D3 refused a toast for a
    /// single ✕ because a snag carries no authored content — no name, no colour, no rating — so
    /// there was nothing for an undo to give back that a second tap could not. That argument is
    /// about *one anonymous timestamp*, and it does not survive being multiplied: what a set of
    /// marks encodes is **where a passage gives trouble**, and the only way to remake it is to play
    /// the passage again and trip in the same places. The clearing is also the one snag action that
    /// can be aimed at rows you cannot all see at once.
    ///
    /// Deferred, not delete-then-restore, like every other bulk delete on this screen: the rows hide
    /// now and the objects are destroyed when the window closes, so a missed commit costs a delete
    /// that did not happen rather than data that cannot come back.
    func deleteSelectedSnags() {
        deleteSnags(selectedSnags)
        snagSelection.reconcile(with: snagsByTime.map(\.uid))
    }

    private func deleteSnags(_ targets: [Snag]) {
        guard !targets.isEmpty else { return }
        let uids = Set(targets.map(\.uid))
        withAnimation(.easeOut(duration: 0.2)) { pendingDeletedSnagUIDs.formUnion(uids) }

        // No name to read back — a snag has none — so the count is the whole message. Singular is
        // still reachable: selecting one row and tapping the trash is a legitimate way through.
        let message = targets.count == 1 ? "Deleted 1 snag" : "Deleted \(targets.count) snags"
        presentUndo(message) { [weak self] in
            guard let self else { return }
            withAnimation(.easeOut(duration: 0.2)) { self.pendingDeletedSnagUIDs.subtract(uids) }
        } commit: { [weak self] in
            guard let self else { return }
            for snag in self.song.snags where uids.contains(snag.uid) { self.context.delete(snag) }
            self.pendingDeletedSnagUIDs.subtract(uids)
            // The offer was raised from marks that no longer describe the same cluster.
            if self.offeringSnagTighten, self.snagTightenProposal == nil { self.offeringSnagTighten = false }
        }
    }
}
