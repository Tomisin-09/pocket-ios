import Foundation
import SwiftData

/// Everything the song map writes (ADR 0232): a piece made in a gap (D9), copies of a piece (D16), how far
/// a loop repeats (D14, D15), what *Put it together* needs (D11), and taking back what it just made (D17).
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

    // MARK: - Put it together (D11)

    /// What Put it together writes before the routine opens: the command tempos the player gave, the
    /// backing switch for a line over its chords, and a loop for each joined stretch, in the order of
    /// `plan.joins`. Saved at once, since the review builds the routine in a context of its own and reads
    /// the store.
    static func prepare(_ plan: SongMapTogether.Plan, commands: [UUID: Double], in song: Song,
                        context: ModelContext) -> [Loop] {
        for (uid, command) in commands {
            song.loops.first { $0.uid == uid }?.promoteCommand(to: command)
        }
        if let backing = plan.backing { song.loops.first { $0.uid == backing }?.isBackingTrack = true }
        let joined = plan.joins.compactMap { join($0, in: song, context: context) }
        try? context.save()
        return joined
    }

    /// A joined stretch: from its first part's start to its last part's end, at the slowest of their
    /// speeds and command tempos, typed to stay on their layer. It holds no piece: its parts hold the notes.
    private static func join(_ join: SongMapTogether.Join, in song: Song, context: ModelContext) -> Loop? {
        let parts = join.parts.compactMap { uid in song.loops.first { $0.uid == uid } }
        guard let first = parts.first, let last = parts.last, last.end > first.start else { return nil }
        let loop = Loop(name: join.name, start: first.start, end: last.end,
                        speed: parts.map(\.speed).min() ?? 1, repeats: 4)
        loop.commandTempo = parts.compactMap(\.commandTempo).min()
        let types = Set(parts.map(\.loopType))
        if join.layer == .chords {
            loop.loopType = .chords
        } else if types.count == 1, let type = types.first, type != .chords {
            loop.loopType = type
        }
        insert(loop, into: song, context: context)
        return loop
    }

    /// The routine, built in the review's own context (ADR 0111's flow), so nothing lands in Routines until
    /// Save. Each block runs at its loop's own length, as a block added by hand does. A loop that can't be
    /// found there is left out, as a planned block whose unit has gone is.
    static func routine(named name: String, runs: [SongMapTogether.Run], in context: ModelContext) -> Routine {
        let loops = (try? context.fetch(FetchDescriptor<Loop>())) ?? []
        let byUID = Dictionary(loops.map { ($0.uid, $0) }, uniquingKeysWith: { first, _ in first })
        let routine = Routine(name: name)
        context.insert(routine)
        var order = 0
        for run in runs {
            guard let loop = byUID[run.uid] else { continue }
            let item = run.mode == .improvise ? RoutineItem.improviseLoopItem(loop, order: order)
                : RoutineItem.item(loop, kind: .focused, order: order)
            item.routine = routine
            context.insert(item)
            order += 1
        }
        return routine
    }

    /// Whether a saved routine has a block on any of these loops: once one does, they're its blocks, and
    /// Undo no longer takes them back. Fetched, not read off the loops, whose relationships don't hear of a
    /// save made in another context.
    static func routineUses(_ uids: Set<UUID>, context: ModelContext) -> Bool {
        let items = (try? context.fetch(FetchDescriptor<RoutineItem>())) ?? []
        return items.contains { item in item.loop.map { uids.contains($0.uid) } ?? false }
    }

    private static func insert(_ loop: Loop, into song: Song, context: ModelContext) {
        context.insert(loop)
        Analytics.send(.loopCreated)
        loop.song = song
    }
}
