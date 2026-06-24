import SwiftUI

/// Loop / marker **deletion with undo** (ADR 0019), split out of `+Actions.swift` to keep
/// each file under the length budget. Both deletes snapshot enough to rebuild the item
/// (same `uid`) so the Undo toast restores it exactly — including, for a loop, its
/// automator config and last-practiced speed (ADR 0040).
extension WaveformPracticeModel {

    /// Delete a loop, with an Undo toast (ADR 0019). Edits to an existing loop are
    /// written straight to the @Model by its edit sheet (auto-persisting), so there's
    /// no `updateLoop`. Undo re-creates the loop from a snapshot (same uid + automator +
    /// last-practiced speed) and restores it as active if it was.
    func deleteLoop(_ loop: Loop) {
        let wasActive = activeLoopID == loop.uid
        if wasActive {
            // Clean state (ADR 0029): deleting the loop you're hearing plays through
            // the song rather than silently arming a different saved region. Cleared
            // *before* the delete so the `activeLoopID` didSet (ADR 0040) persists this
            // loop's last-practiced speed while it's still live, not on a deleted object.
            activeLoopID = nil
            applyActiveLoopToEngine()
        }
        let (uid, name) = (loop.uid, loop.name)
        let (start, end, lspeed, repeats) = (loop.start, loop.end, loop.speed, loop.repeats)
        let lastPracticed = loop.lastPracticedSpeed
        let automator = loop.automator
        context.delete(loop)
        presentUndo("Deleted \(name)") { [weak self] in
            guard let self else { return }
            let restored = Loop(name: name, start: start, end: end, speed: lspeed, repeats: repeats)
            restored.uid = uid
            restored.lastPracticedSpeed = lastPracticed
            restored.automator = automator
            self.context.insert(restored)
            restored.song = self.song
            if wasActive {
                self.activeLoopID = restored.uid
                self.applyActiveLoopToEngine()
            }
        }
    }

    /// Delete a marker, with an Undo toast (ADR 0019). Undo re-creates it from a
    /// snapshot (same uid).
    func deleteMarker(_ marker: Marker) {
        let (uid, seconds, label) = (marker.uid, marker.seconds, marker.label)
        context.delete(marker)
        presentUndo("Deleted \(label)") { [weak self] in
            guard let self else { return }
            let restored = Marker(seconds: seconds, label: label)
            restored.uid = uid
            self.context.insert(restored)
            restored.song = self.song
        }
    }
}
