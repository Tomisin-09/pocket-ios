import SwiftUI

/// A copy the map made, while it's still as the map made it (ADR 0310 D4, D5): shifted a beat, with an Undo,
/// or removed, asked first. Apart from `SongMapView` only to keep each file within its length budget.
extension SongMapView {

    /// *Shift a beat earlier* or *later* (D4): moved at once and drawn heavier for a moment, with an Undo that
    /// puts the piece back as it was.
    func shift(_ uid: UUID, by beats: Int, grid: SongMapInput.Grid?) {
        guard let grid, let loop = song.loops.first(where: { $0.uid == uid }),
              let before = SongMapWriter.shift(uid, by: beats, grid: grid, in: song) else { return }
        highlighted = [uid]
        let way = beats < 0 ? "earlier" : "later"
        withAnimation(.easeOut(duration: 0.2)) {
            made = Made(message: "Shifted \(loop.name) a beat \(way)", uids: [],
                        restore: Restore(uid: uid, piece: before))
        }
    }

    /// *Remove copy* (D5): ask first.
    func askToRemove(_ uid: UUID) {
        made = nil
        removing = CopySource(uid: uid)
    }

    /// The copy being asked about, by name, for the question.
    var removingName: String {
        removing.flatMap { source in song.loops.first { $0.uid == source.uid }?.name } ?? ""
    }

    /// Remove it, or say why not: the store can know of a routine block or a practice run that the loop's
    /// own relationships don't (`SongMapWriter.removeCopy`).
    func confirmRemove(_ uid: UUID) {
        if !SongMapWriter.removeCopy(uid, held: heldLoop, from: song, context: modelContext) {
            removalRefused = true
        }
    }
}

/// The question *Remove copy* asks, and what it says when the copy turns out to be the player's (ADR 0310
/// D5). At the map's root, never on a row: a presentation raised from a row can lose its write (iOS 18).
struct SongMapCopyPrompts: ViewModifier {
    @Binding var removing: SongMapView.CopySource?
    @Binding var refused: Bool
    let name: String
    let onRemove: (UUID) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog("Remove \(name)?", isPresented: Binding(get: { removing != nil },
                                                                     set: { if !$0 { removing = nil } }),
                                titleVisibility: .visible, presenting: removing) { source in
                Button("Remove copy", role: .destructive) { onRemove(source.uid) }
                Button("Cancel", role: .cancel) {}
            } message: { _ in
                Text("It's a copy the map made, and you haven't changed it. Removing it can't be undone, but you "
                     + "can copy the piece again.")
            }
            .alert("This copy stays", isPresented: $refused) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("It's been practised or put in a routine since it was made, so it's yours now. To delete it, "
                     + "use the waveform.")
            }
    }
}
