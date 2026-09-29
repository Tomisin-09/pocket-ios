import Foundation
import SwiftData

/// Everything the song map writes (ADR 0232): a piece made in a gap (D9), copies of a piece (D16), how far
/// a loop repeats (D14, D15), and taking back what it just made (D17).
///
/// **The map removes only loops it has just made.** A loop made on the waveform is never deleted from
/// here: deleting stays on the waveform, where the loop is drawn and its delete has an Undo of its own.
@MainActor
enum SongMapWriter {

    /// *Make a piece here* (D9): a loop that fills the gap exactly, named after its section and lane and
    /// typed *Chords* on the chords lane, so it lands where it was asked for.
    static func make(_ gap: SongMap.Gap, in song: Song, context: ModelContext) -> Loop? {
        guard song.duration > 0 else { return nil }
        let loop = Loop(name: SongMapLayout.unusedName(gap.name, among: song.loops.map(\.name)),
                        start: gap.start / song.duration, end: gap.end / song.duration, speed: 1, repeats: 4)
        if gap.layer == .chords { loop.loopType = .chords }
        insert(loop, into: song, context: context)
        return loop
    }

    /// *Copy to…* (D16): a loop over each target with `source`'s piece written across it, typed as the
    /// source is. A target no tap lands in makes nothing.
    static func copy(_ source: Loop, into targets: [SongMapCopy.Target], grid: SongMapInput.Grid?,
                     in song: Song, context: ModelContext) -> [Loop] {
        guard song.duration > 0, let piece = source.transcription else { return [] }
        let from = SongMapCopy.Source(piece: piece, start: source.start * song.duration,
                                      end: source.end * song.duration)
        let copies = SongMapCopy.copies(of: from, into: targets, grid: grid,
                                        existingNames: song.loops.map(\.name), now: .now)
        return copies.map { copy in
            let loop = Loop(name: copy.name, start: copy.start / song.duration, end: copy.end / song.duration,
                            speed: 1, repeats: 4)
            loop.loopType = source.loopType
            loop.transcription = copy.piece
            insert(loop, into: song, context: context)
            return loop
        }
    }

    /// How far a loop repeats (D14, D15), from a piece's hold menu: `nil` when it doesn't.
    static func setRepeats(_ uid: UUID, _ reach: SongMap.RepeatsTo?, in song: Song) {
        guard let loop = song.loops.first(where: { $0.uid == uid }) else { return }
        loop.repeatsToSectionEnd = reach != nil
        loop.repeatsTo = reach?.stored
    }

    /// Undo (D17): the loops the map just made, and nothing else. They're new, so nothing hangs off them
    /// yet: the Undo ends as soon as one is opened.
    static func takeBack(_ uids: Set<UUID>, from song: Song, context: ModelContext) {
        let made = song.loops.filter { uids.contains($0.uid) }
        // Off the song first, so the map's next drawing, which reads every loop's fields, can't reach one
        // that's already deleted.
        song.loops.removeAll { uids.contains($0.uid) }
        for loop in made { context.delete(loop) }
    }

    private static func insert(_ loop: Loop, into song: Song, context: ModelContext) {
        context.insert(loop)
        Analytics.send(.loopCreated)
        loop.song = song
    }
}
